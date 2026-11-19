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

    # Capture long nix output to temp files: pipe capture inside each+try
    # deadlocks once the child writes past the pipe buffer.
    let tmp_runtime = (mktemp)
    let tmp_build = (mktemp)

    let result = (
      try {
        # Use nix path-info --recursive to get all dependencies
        nix path-info --recursive $path o> $tmp_runtime
        let closure = (open $tmp_runtime | lines | where {|line| ($line | str trim | is-not-empty) })

        # Build closure: derivation inputs and intermediate outputs
        let build_closure = (
          try {
            let deriver = (nix-store --query --deriver $path | lines | first | str trim)

            # Never pass unknown-deriver to nix-store -qR: it resolves as a
            # relative path against the CWD and fails.
            if ($deriver == "unknown-deriver") {
              $"No recorded deriver for ($path), using runtime closure only" | ci log info
              []
            } else {
              nix-store -qR --include-outputs $deriver o> $tmp_build
              open $tmp_build | lines | where {|line| ($line | str trim | is-not-empty) }
            }
          } catch {|err|
            $"Failed to get build closure for ($path): ($err.msg)" | ci log info
            []
          }
        )

        let merged = ($closure ++ $build_closure | uniq)

        $"Got ($merged | length) paths in closure for ($path) - runtime: ($closure | length), build: ($build_closure | length)" | ci log info
        $merged
      } catch {|err|
        $"Failed to get closure for ($path): ($err.msg)" | ci log error
        []
      }
    )

    rm -f $tmp_runtime $tmp_build
    $result
  } | flatten | uniq
}

# Check cache status or push store paths to binary cache (pipeline-friendly)
export def "ci nix cache" [
  cache: string # Target cache: https://<name>.cachix.org, a cachix cache name, or a store URI (s3://..., file://...)
  --upstream: string # Deprecated: the upstream check was removed; accepted for compatibility and ignored
  --dry-run # Report what would be pushed without spawning cachix or nix
]: [
  list<string> -> table
] {
  # Derivations are KB-sized text regenerated by evaluation - never worth pushing
  let paths = ($in | where {|p| ($p | str ends-with '.drv') == false })

  if ($paths | is-empty) {
    "No paths provided" | ci log error
    return []
  }

  if ($upstream | is-not-empty) {
    "Upstream check removed; deprecated --upstream flag ignored" | ci log info
  }

  # Kept for consumers that still read the column
  let upstream_value = if ($upstream | is-empty) { null } else { $upstream }

  let is_cachix_url = ($cache =~ '^https?://.*\.cachix\.org')
  let is_uri = ($cache =~ '^[a-z][a-z0-9+.-]*://')
  let cache_name = if $is_cachix_url {
    ($cache | parse 'https://{name}.cachix.org' | get name.0)
  } else {
    $cache
  }

  if $dry_run {
    $"Dry-run: would push ($paths | length) paths to ($cache) in one batch - sample: ($paths | first 3 | str join ', ')" | ci log info
    return (
      $paths | each {|path|
        {path: $path cached: null upstream: $upstream_value cache: $cache status: "dry-run" error: null}
      }
    )
  }

  # One batched invocation for the whole set: 1138 paths x ~80 bytes is ~91 KB,
  # far below the macOS ARG_MAX limit (1 MB). stdout goes to a temp file because
  # pipe capture deadlocks once the output passes the pipe buffer (same reason
  # as the redirects in `ci nix closure`); cachix progress stays on stderr.
  let tmp = (mktemp)
  let push_result = (
    try {
      if $is_cachix_url or (not $is_uri) {
        cachix push $cache_name ...$paths o> $tmp
      } else {
        nix copy --to $cache ...$paths o> $tmp
      }
      {ok: true error: null}
    } catch {|err|
      {ok: false error: $err.msg}
    }
  )

  let output = (open $tmp | lines | where {|line| ($line | str trim | is-not-empty) })
  rm -f $tmp

  if $push_result.ok {
    if ($output | is-not-empty) {
      $output | each {|line| $line | ci log info }
    }
    $"Pushed ($paths | length) paths to ($cache) in one batch" | ci log info

    $paths | each {|path|
      {path: $path cached: false upstream: $upstream_value cache: $cache status: "success" error: null}
    }
  } else {
    let err_text = if ($output | is-empty) {
      $push_result.error
    } else {
      $"($push_result.error): ($output | first 3 | str join ' | ')"
    }
    $"Failed to push ($paths | length) paths to ($cache): ($err_text)" | ci log error

    [{path: "batch" cached: false upstream: $upstream_value cache: $cache status: "error" error: $err_text}]
  }
}

# Publish the closures of build rows to a binary cache: rows in, honest rows out
export def "ci nix publish" [
  cache: string # Target cache: cachix name, https://<name>.cachix.org, or a store URI
  --dry-run # Report the batch plan without spawning cachix or nix copy
]: [
  list<record> -> list<record>
] {
  let build_rows = $in
  let paths = (
    $build_rows
    | each {|row| $row | get -o path }
    | compact
    | where {|path| $path | is-not-empty }
  )

  if ($paths | is-empty) {
    "No store paths in the input rows, nothing to publish" | ci log info
    return []
  }

  # ci nix closure is the only nix query publish makes, and it drains to files
  let pushable = (
    $paths
    | ci nix closure
    | where {|path| not ($path | str ends-with '.drv') }
    | uniq
    | sort
  )

  if ($pushable | is-empty) {
    "The closure holds no pushable paths, nothing to publish" | ci log info
    return []
  }

  let batches = (batch-plan $pushable (200 * 1024))
  let bytes = ($pushable | each {|path| ($path | str length) + 1 } | math sum)

  if $dry_run {
    $"Dry-run: would push ($pushable | length) paths, ~($bytes / 1024 | math round) KB, ($batches | length) batches to ($cache)" | ci log info
    return []
  }

  let result = (push-batches $cache $pushable)
  let failed = ($result.rows | where status == "failed")

  if ($failed | is-empty) {
    let uploaded = ($result.rows | where status == "uploaded" | length)
    $"Pushed ($uploaded) of ($result.rows | length) paths to ($cache)" | ci log info
  } else {
    for row in $failed {
      $"Failed to push ($row.path): ($row.error)" | ci log error | ignore
    }

    # A command cannot return rows and set an exit code: failing the command is the gate
    error make {
      msg: $"Publish to ($cache) failed: ($failed | length) of ($result.rows | length) paths. First: ($failed.0.path): ($failed.0.error)"
    }
  }

  $result.rows
}

# Split paths into batches that keep the argv under the byte budget
def batch-plan [paths: list<string>, budget: int] {
  mut batches = []
  mut current = []
  mut size = 0

  for path in $paths {
    let cost = (($path | str length) + 1)

    if (($size + $cost) > $budget) and ($current | is-not-empty) {
      $batches = ($batches | append [$current])
      $current = []
      $size = 0
    }

    $current = ($current | append $path)
    $size = $size + $cost
  }

  if ($current | is-not-empty) {
    $batches = ($batches | append [$current])
  }

  $batches
}

# Read a drained stream file back as non-empty lines
def drain-lines [log_file: string] {
  if ($log_file | path exists) {
    open --raw $log_file | lines | where {|line| $line | str trim | is-not-empty }
  } else {
    []
  }
}

# A store URI is pushed with nix copy; every other target is a cachix cache
def is-store-uri [cache: string] {
  ($cache !~ '^https?://.*\.cachix\.org') and ($cache =~ '^[a-z][a-z0-9+.-]*://')
}

# Reduce a cachix URL to the cache name the CLI expects
def cachix-name [cache: string] {
  if ($cache =~ '^https?://.*\.cachix\.org') {
    $cache | parse 'https://{name}.cachix.org' | get name.0
  } else {
    $cache
  }
}

# Error text for a failed batch: the caught message plus the drained stream tail
def push-error-tail [failure: any, lines: list<string>] {
  let tail = ($lines | last 5 | str join " | ")

  if ($failure | is-not-empty) and ($tail | is-not-empty) {
    $"($failure): ($tail)"
  } else if ($failure | is-not-empty) {
    $failure
  } else if ($tail | is-not-empty) {
    $tail
  } else {
    "push failed without output"
  }
}

# Exit code of a push attempt: 0 on success, never 0 on failure
def push-exit-code [failure: any, last_exit_code: int] {
  if ($failure == null) {
    0
  } else if $last_exit_code == 0 {
    1
  } else {
    $last_exit_code
  }
}

# Run one push invocation and parse the drained streams into an uploaded set
def push-batch [cache: string, batch: list<string>] {
  let out_log = (mktemp)
  let err_log = (mktemp)

  # Both streams drain to files: piping push output into nu capture deadlocks
  let failure = (
    try {
      if (is-store-uri $cache) {
        nix copy --to $cache ...$batch o> $out_log err> $err_log
      } else {
        cachix push (cachix-name $cache) ...$batch o> $out_log err> $err_log
      }
      null
    } catch {|err|
      $err.msg
    }
  )

  # Read the code before any later external resets it
  let last_exit_code = ($env.LAST_EXIT_CODE? | default "1" | into int)

  let lines = ((drain-lines $out_log) ++ (drain-lines $err_log))
  rm -f $out_log $err_log

  let uploaded = ($lines | parse -r '^Pushing (?P<path>\S+)' | get path | uniq)

  {
    ok: ($failure == null)
    exit_code: (push-exit-code $failure $last_exit_code)
    uploaded: $uploaded
    error: (push-error-tail $failure $lines)
  }
}

# Push every path in serial batches with one retry per failed batch
# Skipped rows are the complement of the uploaded set in a successful batch
# Failed rows are the complement of the uploaded set after the retry also fails
# Every batch logs index/total, argv size, exit code and the parsed row counts
def push-batches [cache: string, paths: list<string>] {
  let pushable = (
    $paths
    | where {|path| ($path | is-not-empty) and (not ($path | str ends-with '.drv')) }
    | uniq
    | sort
  )

  let batches = (batch-plan $pushable (200 * 1024))
  let total = ($batches | length)

  mut rows = []
  mut ok = true

  for entry in ($batches | enumerate) {
    let index = ($entry.index + 1)
    let batch = $entry.item
    let argv_kb = (($batch | each {|path| ($path | str length) + 1 } | math sum) / 1024 | math round)

    mut pushed = (push-batch $cache $batch)

    if not $pushed.ok {
      $"Batch ($index)/($total): push failed, exit code ($pushed.exit_code), retrying once" | ci log warning | ignore
      $"Batch ($index)/($total) stderr: ($pushed.error)" | ci log warning | ignore
      $pushed = (push-batch $cache $batch)
    }

    if not $pushed.ok {
      $ok = false
    }

    # A closure cannot read a mutable binding, so publish the batch from an immutable copy
    let push = $pushed
    let batch_rows = (
      $batch | each {|path|
        if $path in $push.uploaded {
          {path: $path status: "uploaded" error: null}
        } else if $push.ok {
          {path: $path status: "skipped" error: null}
        } else {
          {path: $path status: "failed" error: $push.error}
        }
      }
    )

    let uploaded_count = ($batch_rows | where status == "uploaded" | length)
    let skipped_count = ($batch_rows | where status == "skipped" | length)
    let failed_count = ($batch_rows | where status == "failed" | length)
    let outcome = $"Batch ($index)/($total): ($batch | length) paths, ~($argv_kb) KB argv, exit ($push.exit_code), uploaded ($uploaded_count), skipped ($skipped_count), failed ($failed_count)"

    if $push.ok {
      $outcome | ci log info | ignore
    } else {
      $outcome | ci log error | ignore
      $"Batch ($index)/($total) stderr: ($push.error)" | ci log error | ignore
    }

    $rows = ($rows | append $batch_rows)
  }

  {rows: $rows ok: $ok}
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
