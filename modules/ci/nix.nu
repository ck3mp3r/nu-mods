use ../common/help show-help
use std/log

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
    let host_info = (sys host)
    let system = ($host_info | get long_os_version | parse "{name} {version}" | get name.0)
    let arch = ($host_info | get arch)
    match [$system $arch] {
      ["Darwin" "aarch64"] => "aarch64-darwin"
      ["Darwin" "x86_64"] => "x86_64-darwin"
      ["Linux" "aarch64"] => "aarch64-linux"
      ["Linux" "x86_64"] => "x86_64-linux"
      _ => {
        log error $"Unsupported system: ($system) ($arch)"
        "unknown"
      }
    }
  } catch {
    log error "Failed to detect system"
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
    # Handle both directory paths and flake.nix file paths
    let check_path = if ($path | str ends-with "flake.nix") {
      $path
    } else {
      $path | path join "flake.nix"
    }

    if ($check_path | path exists) {
      # Return the directory path, not the flake.nix path
      if ($path | str ends-with "flake.nix") {
        $path | path dirname
      } else {
        $path
      }
    } else {
      null
    }
  } | compact
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

  log info $"Checking ($flakes | length) flakes"

  $flakes | each {|flake|
    log info $"Checking: ($flake)"

    let result = try {
      mut cmd_args = []

      if $flake != "." {
        $cmd_args = ($cmd_args | append ["--flake" $flake])
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
      log error $"Check failed for ($flake): ($err.msg)"
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
    log info $"Updating input '($input)' in ($flakes | length) flakes"
  } else {
    log info $"Updating all inputs in ($flakes | length) flakes"
  }

  $flakes | each {|flake|
    let flake_path = if $flake == "." { "." } else { $"--flake ($flake)" }

    let result = try {
      if ($input | is-not-empty) {
        log info $"Updating ($input) in ($flake)"
        if $flake == "." {
          nix flake update $input
        } else {
          nix flake update $input --flake $flake
        }
        {flake: $flake input: $input status: "success" error: null}
      } else {
        log info $"Updating all inputs in ($flake)"
        if $flake == "." {
          nix flake update
        } else {
          nix flake update --flake $flake
        }
        {flake: $flake input: "all" status: "success" error: null}
      }
    } catch {|err|
      log error $"Update failed for ($flake): ($err.msg)"
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

  log info $"Listing packages from ($flakes | length) flakes"

  $flakes | each {|flake|
    log info $"Listing packages in ($flake)"

    try {
      let flake_info = if $flake == "." {
        nix flake show --json | from json
      } else {
        nix flake show --flake $flake --json | from json
      }

      if "packages" in $flake_info {
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
      log error $"Failed to list packages for ($flake): ($err.msg)"
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

  log info $"Building from ($flakes | length) flakes"

  $flakes | each {|flake|
    if ($packages_to_build | is-empty) {
      # Build all packages for current system
      log info $"Building all packages in ($flake)"

      try {
        let flake_info = if $flake == "." {
          nix flake show --json | from json
        } else {
          nix flake show --flake $flake --json | from json
        }

        if "packages" not-in $flake_info {
          log warning $"No packages found in ($flake)"
          []
        } else {
          let packages = $flake_info.packages

          # Use detected system or fallback to first available system
          let target_system = if $current_system in ($packages | columns) {
            $current_system
          } else if $current_system == "unknown" and (($packages | columns | length) > 0) {
            let first_system = ($packages | columns | first)
            log warning $"System detection failed, using first available system: ($first_system)"
            $first_system
          } else {
            log warning $"No packages for system ($current_system) in ($flake)"
            return []
          }

          let system_packages = ($packages | get $target_system | columns)

          $system_packages | each {|pkg|
            log info $"Building ($pkg) from ($flake)"

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
              log error $"Failed to build ($pkg): ($err.msg)"
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
        log error $"Failed to get flake info for ($flake): ($err.msg)"
        []
      }
    } else {
      # Build specific packages
      $packages_to_build | each {|pkg|
        log info $"Building ($pkg) from ($flake)"

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
          log error $"Failed to build ($pkg): ($err.msg)"
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

# Push store paths to binary cache (pipeline-friendly)
export def "ci nix cache" [
  --cache: string # Cache URI (e.g., s3://bucket, cachix, file:///path)
]: [
  list<string> -> table
] {
  let paths = $in

  if ($paths | is-empty) {
    log error "No paths provided to push"
    return []
  }

  if ($cache | is-empty) {
    log error "No cache URI provided (use --cache)"
    return []
  }

  log info $"Pushing ($paths | length) paths to ($cache)"

  $paths | each {|path|
    log info $"Pushing ($path)"

    try {
      nix copy --to $cache $path
      {
        path: $path
        cache: $cache
        status: "success"
        error: null
      }
    } catch {|err|
      log error $"Failed to push ($path): ($err.msg)"
      {
        path: $path
        cache: $cache
        status: "failed"
        error: $err.msg
      }
    }
  }
}
