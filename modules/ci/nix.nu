use ../common/help show-help
use std/log

# Nix flake operations - show help
export def "ci nix" [] {
  show-help "ci nix"
}

# ============================================================================
# FLAKE COMMANDS
# ============================================================================

# Nix flake operations - show help
export def "ci nix flake" [] {
  show-help "ci nix flake"
}

# Check flake for issues
export def "ci nix flake check" [
  --flake: string = "." # Path to flake (default: current directory)
]: [
  nothing -> nothing
] {
  log info $"Checking flake at: ($flake)"

  try {
    if $flake != "." {
      nix flake check --flake $flake
    } else {
      nix flake check
    }
    print "✓ Flake check passed"
  } catch {|err|
    log error $"Flake check failed: ($err.msg)"
    error make {msg: $"Flake check failed: ($err.msg)"}
  }
}

# Update flake inputs
export def "ci nix flake update" [
  input?: string # Specific input to update (optional - updates all if not provided)
  --flake: string = "." # Path to flake
]: [
  nothing -> nothing
] {
  if ($input | is-not-empty) {
    log info $"Updating flake input: ($input)"
    try {
      nix flake update $input
      print $"✓ Updated input: ($input)"
    } catch {|err|
      log error $"Failed to update ($input): ($err.msg)"
    }
  } else {
    log info "Updating all flake inputs"
    try {
      nix flake update
      print "✓ Updated all inputs"
    } catch {|err|
      log error $"Failed to update inputs: ($err.msg)"
    }
  }
}

# Show flake outputs
export def "ci nix flake show" [
  --flake: string = "." # Path to flake
]: [
  nothing -> nothing
] {
  log info "Showing flake outputs"

  try {
    let output = (nix flake show --json | from json)
    print ($output | to yaml)
  } catch {|err|
    log error $"Failed to show flake: ($err.msg)"
  }
}

# List all buildable packages in the flake
export def "ci nix flake list-packages" [
  --flake: string = "." # Path to flake
]: [
  nothing -> nothing
] {
  log info "Listing buildable packages"

  try {
    let flake_info = (nix flake show --json | from json)

    if "packages" in $flake_info {
      let packages = $flake_info.packages

      for system in ($packages | columns) {
        print $"\n($system):"
        for pkg in ($packages | get $system | columns) {
          print $"  - ($pkg)"
        }
      }
    } else {
      print "No packages found in flake"
    }
  } catch {|err|
    log error $"Failed to list packages: ($err.msg)"
  }
}

# Build flake packages
export def "ci nix flake build" [
  package?: string # Specific package to build (optional - builds all if not provided)
  --flake: string = "." # Path to flake
]: [
  nothing -> nothing
] {
  if ($package | is-not-empty) {
    # Build specific package
    log info $"Building package: ($package)"
    try {
      let store_path = (nix build $".#($package)" --print-out-paths --no-link | str trim)
      print $"✓ Built ($package): ($store_path)"
      print $store_path
    } catch {|err|
      log error $"Failed to build ($package): ($err.msg)"
    }
  } else {
    # Build all packages
    log info "Building all packages"
    try {
      let flake_info = (nix flake show --json | from json)

      if "packages" not-in $flake_info {
        print "No packages found in flake"
        return
      }

      let packages = $flake_info.packages

      # Determine the current Nix system
      let nix_system = try {
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
            return
          }
        }
      } catch {
        # Fallback to first available system if sys host fails (e.g., in tests)
        ($packages | columns | first)
      }

      if $nix_system not-in ($packages | columns) {
        print $"No packages for system: ($nix_system)"
        return
      }

      let system_packages = ($packages | get $nix_system | columns)
      mut store_paths = []

      for pkg in $system_packages {
        log info $"Building ($pkg)"
        try {
          let path = (nix build $".#($pkg)" --print-out-paths --no-link | str trim)
          print $"✓ Built ($pkg): ($path)"
          $store_paths = ($store_paths | append $path)
        } catch {|err|
          log error $"Failed to build ($pkg): ($err.msg)"
        }
      }

      print $"\nBuilt ($store_paths | length) packages:"
      for path in $store_paths {
        print $"  ($path)"
      }
    } catch {|err|
      log error $"Failed to build packages: ($err.msg)"
    }
  }
}

# ============================================================================
# CACHE COMMANDS
# ============================================================================

# Nix cache operations - show help
export def "ci nix cache" [] {
  show-help "ci nix cache"
}

# Push store paths to binary cache
export def "ci nix cache push" [
  ...paths: string # Store paths to push
  --cache: string # Cache URI (e.g., s3://bucket, file:///path)
]: [
  nothing -> nothing
] {
  if ($paths | is-empty) {
    log error "No paths provided to push"
    return
  }

  if ($cache | is-empty) {
    log error "No cache URI provided (use --cache)"
    return
  }

  log info $"Pushing ($paths | length) paths to ($cache)"

  try {
    nix copy --to $cache ...$paths
    print $"✓ Pushed ($paths | length) paths to cache"
    for path in $paths {
      print $"  ($path)"
    }
  } catch {|err|
    log error $"Failed to push to cache: ($err.msg)"
    error make {msg: $"Failed to push to cache: ($err.msg)"}
  }
}
