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

# Extract packages from flake show output (supports both v1 and v2 formats)
# Returns: { <system>: [pkg1, pkg2, ...], ... }
def extract-packages-from-flake-info []: [record -> record] {
  let flake_info = $in

  # Check for new format (v2) with inventory structure
  if ($flake_info != null) and ("inventory" in $flake_info) and ("packages" in $flake_info.inventory) {
    let packages_output = $flake_info.inventory.packages.output.children

    $packages_output | columns | each {|system|
      let system_data = $packages_output | get $system

      # Check if this system has children (packages) or is filtered
      if ("children" in $system_data) {
        {$system: ($system_data.children | columns)}
      } else {
        {}
      }
    } | reduce --fold {} {|it acc| $acc | merge $it }
  } else if ($flake_info != null) and ("packages" in $flake_info) {
    # Legacy format (v1) - direct packages structure
    let packages = $flake_info.packages

    $packages | columns | each {|system|
      {$system: ($packages | get $system | columns)}
    } | reduce --fold {} {|it acc| $acc | merge $it }
  } else {
    {}
  }
}

# Detect current Nix system
def detect-system []: [nothing -> string] {
  try {
    nix eval --impure --expr 'builtins.currentSystem' | str trim | str replace -a '"' ''
  } catch {|err|
    $"Failed to detect system: ($err.msg)" | ci log warning
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

      let packages_by_system = $flake_info | extract-packages-from-flake-info

      $packages_by_system | columns | each {|system|
        let pkg_names = $packages_by_system | get $system

        $pkg_names | each {|pkg_name|
          {
            flake: $flake
            name: $pkg_name
            system: $system
          }
        }
      } | flatten
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

        let packages_by_system = $flake_info | extract-packages-from-flake-info

        if ($packages_by_system | is-empty) {
          $"No packages found in ($flake)" | ci log warning
          []
        } else {
          # Use detected system or fallback to first available system
          let target_system = if $current_system in ($packages_by_system | columns) {
            $current_system
          } else if $current_system == "unknown" and (($packages_by_system | columns | length) > 0) {
            let first_system = ($packages_by_system | columns | first)
            $"System detection failed, using first available system: ($first_system)" | ci log warning
            $first_system
          } else {
            $"No packages for system ($current_system) in ($flake)" | ci log warning
            return []
          }

          let system_packages = ($packages_by_system | get $target_system)

          $system_packages | each {|pkg|
            $"Building ($pkg) from ($flake)" | ci log info

            try {
              let target = if $flake == "." { $".#($pkg)" } else { $"($flake)#($pkg)" }
              mut cmd_args = [$target "--print-out-paths" "--no-update-lock-file"]

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
          mut cmd_args = [$target "--print-out-paths" "--no-update-lock-file"]

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
    $"Getting closure for path: ($path)" | ci log info

    try {
      # Use nix path-info --recursive to get all dependencies
      let closure = (
        nix path-info --recursive $path
        | lines
        | where {|line| ($line | str trim | is-not-empty) }
      )

      $"Got ($closure | length) paths in closure for ($path)" | ci log info
      $closure
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
    {|path|
      try {
        cachix push $cache_name $path
        {exit_code: 0 stdout: "" stderr: ""}
      } catch {|err|
        {exit_code: 1 stdout: "" stderr: $err.msg}
      }
    }
  } else if ($cache =~ '^[a-z][a-z0-9+.-]*://') {
    {|path|
      try {
        nix copy --to $cache $path
        {exit_code: 0 stdout: "" stderr: ""}
      } catch {|err|
        {exit_code: 1 stdout: "" stderr: $err.msg}
      }
    }
  } else {
    {|path|
      try {
        cachix push $cache $path
        {exit_code: 0 stdout: "" stderr: ""}
      } catch {|err|
        {exit_code: 1 stdout: "" stderr: $err.msg}
      }
    }
  }

  $paths | each {|path|
    $"Processing cache for path: ($path)" | ci log info

    # Verify the path exists locally first
    let path_valid = (
      try {
        nix path-info $path
        true
      } catch {|err|
        $"Failed to validate path ($path): ($err.msg)" | ci log error
        false
      }
    )

    if (not $path_valid) {
      $"WARNING: Path ($path) is not valid in local store!" | ci log warning
    }

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

        # Call push function and capture output
        let result = (do $push_fn $path)

        if $result.exit_code == 0 {
          # Log stderr output even on success (cachix outputs progress to stderr)
          if ($result.stderr | is-not-empty) {
            $result.stderr | lines | each {|line| $line | ci log info }
          }
          $"Successfully pushed ($path) to ($cache)" | ci log info
          {cache: $cache status: "success" error: null}
        } else {
          let error_output = ([$result.stdout $result.stderr] | where {|x| ($x | is-not-empty) } | str join "\n")
          $"Failed to push ($path):" | ci log error
          $error_output | lines | each {|line| $line | ci log error }
          {cache: $cache status: "failed" error: $error_output}
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

# Publish a flake output to a binary cache: build, get closure, check caches, push missing
export def "ci nix publish" [
  cache: string # Cache name or URI to push to
  --flake: string = "." # Flake target to build (e.g., ".#myapp")
  --upstream: string = "https://cache.nixos.org" # Upstream cache to check against
]: [
  nothing -> record
] {
  $"Publishing ($flake) to ($cache)" | ci log info

  # Build the flake
  $"Building ($flake)" | ci log info
  try {
    nix build $flake --json --no-link
  } catch {|err|
    $"Failed to build ($flake): ($err.msg)" | ci log error
    return {status: "error" error: $"Failed to build ($flake): ($err.msg)" cache: $cache flake: $flake total_paths: 0 pushed_count: 0 skipped_count: 0}
  }

  # Get the closure (all recursive dependencies)
  $"Getting closure for ($flake)" | ci log info
  let paths = (
    try {
      nix path-info --recursive $flake | lines | where {|line| ($line | str trim | is-not-empty) }
    } catch {|err|
      $"Failed to get closure: ($err.msg)" | ci log error
      return {status: "error" error: $"Failed to get closure: ($err.msg)" cache: $cache flake: $flake total_paths: 0 pushed_count: 0 skipped_count: 0}
    }
  )

  let cachix_url = if ($cache =~ '^https?://.*\.cachix\.org') {
    $cache
  } else {
    $"https://($cache).cachix.org"
  }

  # Check each path against upstream and cachix, push if missing from both
  mut pushed = 0
  mut skipped = 0

  for path in $paths {
    $"Checking cache status for path: ($path)" | ci log info

    # Check upstream cache
    let in_upstream = (
      try {
        nix path-info --store $upstream $path
        true
      } catch {
        false
      }
    )

    # Check cachix cache (if not already in upstream)
    let in_cachix = if $in_upstream {
      true
    } else {
      try {
        nix path-info --store $cachix_url $path
        true
      } catch {
        false
      }
    }

    if $in_upstream or $in_cachix {
      $"Skipping ($path) - already cached" | ci log info
      $skipped = ($skipped + 1)
    } else {
      $"Pushing ($path) to cachix" | ci log info
      let cache_name = if ($cache =~ '^https?://.*\.cachix\.org') {
        ($cache | parse 'https://{name}.cachix.org' | get name.0)
      } else {
        $cache
      }
      try {
        cachix push $cache_name $path
        $pushed = ($pushed + 1)
      } catch {|err|
        $"Failed to push ($path): ($err.msg)" | ci log error
      }
    }
  }

  {status: "success" error: null cache: $cache flake: $flake total_paths: ($paths | length) pushed_count: $pushed skipped_count: $skipped}
}

# Filter records to paths missing from all caches and write a markdown summary
export def "ci nix missing-paths" [
  cache: string # Cache name for the summary table
]: [
  list<record> -> list<string>
] {
  let records = $in

  # Filter to paths missing from both upstream and cachix
  let missing = ($records | where {|r| (not $r.in_upstream) and (not $r.in_cachix) })
  let missing_paths = ($missing | get path)

  # Write summary to GITHUB_STEP_SUMMARY if available
  let summary_file = $env.GITHUB_STEP_SUMMARY?
  if ($summary_file | is-not-empty) {
    let total = ($records | length)
    let missing_count = ($missing | length)

    let summary = $"### Cache Summary\n\n| Cache | Count |\n|---|---|\n| Total paths | ($total) |\n| Missing paths | ($missing_count) |\n"
    $summary | save --append $summary_file
    "Wrote cache summary to GITHUB_STEP_SUMMARY" | ci log info
  }

  $missing_paths
}
