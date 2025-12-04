use ../common/help show-help
use log.nu *

# Nix operations - show help
export def "ci nix" [] {
  show-help "ci nix"
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Normalize input to list of flake paths
def normalize-flakes []: [list<string> -> list<string> string -> list<string> nothing -> list<string>] {
  let input = $in

  if ($input | is-empty) {
    ["."]
  } else if ($input | describe | str starts-with "list") {
    $input
  } else {
    [$input]
  }
}

# Detect current Nix system
def detect-system []: [nothing -> string] {
  try {
    nix eval --impure --expr 'builtins.currentSystem' | str trim | str replace -a '"' ''
  } catch {
    "unknown"
  }
}

# ============================================================================
# FLAKES COMMAND
# ============================================================================

# Filter paths to only include flake directories (pipeline-friendly)
export def "ci nix flakes" []: [
  list<string> -> list<string>
] {
  let paths = $in

  $paths | each {|path|
    if not ($path | path exists) {
      null
    } else if ($path | path type) == "file" {
      # If it's flake.nix, return its parent directory
      if ($path | str ends-with "flake.nix") {
        let dir = ($path | path dirname)
        if ($dir | is-empty) { "." } else { $dir }
      } else {
        null
      }
    } else {
      # It's a directory, check if it contains flake.nix
      if ($path | path join "flake.nix" | path exists) {
        $path
      } else {
        null
      }
    }
  } | compact | uniq
}

# ============================================================================
# CHECK COMMAND
# ============================================================================

# Check flakes for issues (pipeline-friendly)
export def "ci nix check" [
  --impure # Allow impure evaluation
  --args: string # Additional arguments to pass to nix flake check (e.g., "--verbose --option cores 4")
]: [
  list<string> -> table
  string -> table
  nothing -> table
] {
  let flakes = $in | normalize-flakes

  $"Checking ($flakes | length) flakes" | ci log info

  $flakes | each {|flake|
    $"Checking: ($flake)" | ci log info

    let result = try {
      mut cmd_args = []

      # nix flake check takes flake-url as positional argument
      if $flake != "." {
        $cmd_args = ($cmd_args | append $flake)
      }

      if $impure {
        $cmd_args = ($cmd_args | append "--impure")
      }

      if ($args | is-not-empty) {
        $cmd_args = ($cmd_args | append ($args | split row " "))
      }

      nix flake check ...$cmd_args
      {flake: $flake status: "success" error: null}
    } catch {|err|
      $"Check failed for ($flake): ($err.msg)" | ci log error
      {flake: $flake status: "failed" error: $err.msg}
    }

    $result
  }
}

# ============================================================================
# UPDATE COMMAND
# ============================================================================

# Update flake inputs (pipeline-friendly)
export def "ci nix update" [
  input?: string # Specific input to update (optional - updates all if not provided)
]: [
  list<string> -> table
  string -> table
  nothing -> table
] {
  let flakes = $in | normalize-flakes

  if ($input | is-not-empty) {
    $"Updating input '($input)' in ($flakes | length) flakes" | ci log info
  } else {
    $"Updating all inputs in ($flakes | length) flakes" | ci log info
  }

  $flakes | each {|flake|
    let flake_path = if $flake == "." { "." } else { $"--flake ($flake)" }

    let result = try {
      if ($input | is-not-empty) {
        $"Updating ($input) in ($flake)" | ci log info
        if $flake == "." {
          nix flake update $input
        } else {
          nix flake update $input --flake $flake
        }
        {flake: $flake input: $input status: "success" error: null}
      } else {
        $"Updating all inputs in ($flake)" | ci log info
        if $flake == "." {
          nix flake update
        } else {
          nix flake update --flake $flake
        }
        {flake: $flake input: "all" status: "success" error: null}
      }
    } catch {|err|
      $"Update failed for ($flake): ($err.msg)" | ci log error
      {
        flake: $flake
        input: (if ($input | is-not-empty) { $input } else { "all" })
        status: "failed"
        error: $err.msg
      }
    }

    $result
  }
}

# ============================================================================
# PACKAGES COMMAND
# ============================================================================

# List packages from flakes (pipeline-friendly)
export def "ci nix packages" []: [
  list<string> -> table
  string -> table
  nothing -> table
] {
  let flakes = $in | normalize-flakes

  $"Listing packages from ($flakes | length) flakes" | ci log info

  $flakes | each {|flake|
    $"Listing packages in ($flake)" | ci log info

    try {
      let flake_info = if $flake == "." {
        nix flake show --json | from json
      } else {
        nix flake show $flake --json | from json
      }

      if ($flake_info != null) and ("packages" in $flake_info) {
        let packages = $flake_info.packages

        $packages | columns | each {|system|
          let system_packages = $packages | get $system

          $system_packages | columns | each {|pkg_name|
            {
              flake: $flake
              name: $pkg_name
              system: $system
            }
          }
        } | flatten
      } else {
        []
      }
    } catch {|err|
      $"Failed to list packages for ($flake): ($err.msg)" | ci log error
      []
    }
  } | flatten
}

# ============================================================================
# BUILD COMMAND
# ============================================================================

# Build packages from flakes (pipeline-friendly)
export def "ci nix build" [
  ...packages: string # Package names to build (optional - builds all if not provided)
  --impure # Allow impure evaluation
  --args: string # Additional arguments to pass to nix build (e.g., "--option cores 8")
]: [
  list<string> -> table
  string -> table
  nothing -> table
] {
  let flakes = $in | normalize-flakes
  let current_system = detect-system

  let packages_to_build = $packages

  $"Building from ($flakes | length) flakes" | ci log info

  $flakes | each {|flake|
    if ($packages_to_build | is-empty) {
      # Build all packages for current system
      $"Building all packages in ($flake)" | ci log info

      try {
        let flake_info = if $flake == "." {
          nix flake show --json | from json
        } else {
          nix flake show $flake --json | from json
        }

        if ($flake_info == null) or ("packages" not-in $flake_info) {
          $"No packages found in ($flake)" | ci log warning
          []
        } else {
          let packages = $flake_info.packages

          # Use detected system or fallback to first available system
          let target_system = if $current_system in ($packages | columns) {
            $current_system
          } else if $current_system == "unknown" and (($packages | columns | length) > 0) {
            let first_system = ($packages | columns | first)
            $"System detection failed, using first available system: ($first_system)" | ci log warning
            $first_system
          } else {
            $"No packages for system ($current_system) in ($flake)" | ci log warning
            return []
          }

          let system_packages = ($packages | get $target_system | columns)

          $system_packages | each {|pkg|
            $"Building ($pkg) from ($flake)" | ci log info

            try {
              let target = if $flake == "." { $".#($pkg)" } else { $"($flake)#($pkg)" }
              mut cmd_args = [$target "--print-out-paths" "--no-link"]

              if $impure {
                $cmd_args = ($cmd_args | append "--impure")
              }

              if ($args | is-not-empty) {
                $cmd_args = ($cmd_args | append ($args | split row " "))
              }

              let path = (nix build ...$cmd_args | str trim)

              {
                flake: $flake
                package: $pkg
                system: $target_system
                path: $path
                status: "success"
                error: null
              }
            } catch {|err|
              $"Failed to build ($pkg): ($err.msg)" | ci log error
              {
                flake: $flake
                package: $pkg
                system: $target_system
                path: null
                status: "failed"
                error: $err.msg
              }
            }
          }
        }
      } catch {|err|
        $"Failed to get flake info for ($flake): ($err.msg)" | ci log error
        []
      }
    } else {
      # Build specific packages
      $packages_to_build | each {|pkg|
        $"Building ($pkg) from ($flake)" | ci log info

        try {
          let target = if $flake == "." { $".#($pkg)" } else { $"($flake)#($pkg)" }
          mut cmd_args = [$target "--print-out-paths" "--no-link"]

          if $impure {
            $cmd_args = ($cmd_args | append "--impure")
          }

          if ($args | is-not-empty) {
            $cmd_args = ($cmd_args | append ($args | split row " "))
          }

          let path = (nix build ...$cmd_args | str trim)

          {
            flake: $flake
            package: $pkg
            system: $current_system
            path: $path
            status: "success"
            error: null
          }
        } catch {|err|
          $"Failed to build ($pkg): ($err.msg)" | ci log error
          {
            flake: $flake
            package: $pkg
            system: $current_system
            path: null
            status: "failed"
            error: $err.msg
          }
        }
      }
    }
  } | flatten
}

# ============================================================================
# CACHE COMMANDS
# ============================================================================

# Check cache status or push store paths to binary cache (pipeline-friendly)
export def "ci nix cache" [
  cache: string # Target cache URI to push to (e.g., s3://bucket, cachix, file:///path)
  --upstream: string # Upstream cache URI to check if paths are already cached
  --dry-run # Skip pushing to cache (only check upstream if provided)
]: [
  list<string> -> table
] {
  let paths = $in

  if ($paths | is-empty) {
    "No paths provided" | ci log error
    return []
  }

  $paths | each {|path|
    # Check upstream cache if provided
    let upstream_check = if ($upstream | is-not-empty) {
      $"Checking ($path) in upstream cache ($upstream)" | ci log info

      let is_cached = (
        try {
          nix path-info --store $upstream $path
          $"Path ($path) found in upstream cache" | ci log info
          true
        } catch {
          $"Path ($path) not found in upstream cache" | ci log info
          false
        }
      )

      {cached: $is_cached upstream: $upstream}
    } else {
      {cached: null upstream: null}
    }

    # Push to target cache if not dry-run
    let push_result = if (not $dry_run) {
      $"Pushing ($path) to ($cache)" | ci log info

      try {
        nix copy --to $cache $path
        {cache: $cache status: "success" error: null}
      } catch {|err|
        $"Failed to push ($path): ($err.msg)" | ci log error
        {cache: $cache status: "failed" error: $err.msg}
      }
    } else {
      {cache: null status: "success" error: null}
    }

    # Combine results
    {
      path: $path
      cached: $upstream_check.cached
      upstream: $upstream_check.upstream
      cache: $push_result.cache
      status: $push_result.status
      error: $push_result.error
    }
  }
}
