use ../common/help show-help
use log.nu *

# Nix operations - show help
export def "ci nix" [] {
  show-help "ci nix"
}

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

      $cmd_args = ($cmd_args | append "--no-update-lock-file")

      nix flake check ...$cmd_args
      {flake: $flake status: "success" error: null}
    } catch {|err|
      $"Check failed for ($flake): ($err.msg)" | ci log error
      {flake: $flake status: "failed" error: $err.msg}
    }

    $result
  }
}

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
        nix flake show --json --no-update-lock-file | from json
      } else {
        nix flake show $flake --json --no-update-lock-file | from json
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
          nix flake show --json --no-update-lock-file | from json
        } else {
          nix flake show $flake --json --no-update-lock-file | from json
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
              mut cmd_args = [$target "--print-out-paths" "--no-link" "--no-update-lock-file"]

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
          mut cmd_args = [$target "--print-out-paths" "--no-link" "--no-update-lock-file"]

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

# Get closure of store paths (all dependencies) - pipeline-friendly
export def "ci nix closure" []: [
  list<string> -> list<string>
  string -> list<string>
] {
  let paths = $in | if ($in | describe | str starts-with "list") { $in } else { [$in] }

  if ($paths | is-empty) {
    return []
  }

  $paths | each {|path|
    try {
      # Use nix path-info --recursive to get all dependencies
      nix path-info --recursive $path
      | lines
      | where {|line| ($line | str trim | is-not-empty) }
    } catch {|err|
      $"Failed to get closure for ($path): ($err.msg)" | ci log error
      []
    }
  } | flatten | uniq
}

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

  # Determine cache type and push command once before processing paths
  let push_fn = if ($cache =~ '^https?://.*\.cachix\.org') {
    let cache_name = ($cache | parse 'https://{name}.cachix.org' | get name.0)
    {|path| cachix push $cache_name $path }
  } else if ($cache =~ '^[a-z][a-z0-9+.-]*://') {
    {|path| nix copy --to $cache $path }
  } else {
    {|path| cachix push $cache $path }
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

    # Push to target cache if not dry-run AND not already in upstream
    let push_result = if (not $dry_run) {
      # Skip paths already in upstream cache
      if ($upstream_check.cached == true) {
        $"Skipping ($path) - already in upstream cache" | ci log info
        {cache: $cache status: "skipped" error: null}
      } else {
        $"Pushing ($path) to ($cache)" | ci log info

        try {
          do $push_fn $path
          $"Successfully pushed ($path) to ($cache)" | ci log info
          {cache: $cache status: "success" error: null}
        } catch {|err|
          $"Failed to push ($path): ($err.msg)" | ci log error
          {cache: $cache status: "failed" error: $err.msg}
        }
      }
    } else {
      {cache: null status: "dry-run" error: null}
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
