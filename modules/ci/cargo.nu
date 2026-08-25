use ../common/help show-help
use log.nu *

# Cargo operations - show help
export def "ci cargo" [] {
  show-help "ci cargo"
}

# Update package version in Cargo.toml and refresh Cargo.lock
export def "ci cargo update-version" [
  version: string # New version (X.Y.Z format)
]: [
  nothing -> any
] {
  let cargo_toml_path = "Cargo.toml"

  # Read and parse Cargo.toml
  let cargo_toml = try {
    open $cargo_toml_path
  } catch {|err|
    $"Failed to open Cargo.toml: ($err.msg)" | ci log error
    return {status: "error" error: $"Failed to open Cargo.toml: ($err.msg)"}
  }

  # Determine which version field to update
  let has_workspace_version = ($cargo_toml | get -o workspace.package.version? | is-not-empty)
  let has_package_version = ($cargo_toml | get -o package.version? | is-not-empty)

  if not $has_workspace_version and not $has_package_version {
    "No package.version or workspace.package.version found in Cargo.toml" | ci log error
    return {status: "error" error: "No package.version or workspace.package.version found in Cargo.toml"}
  }

  # Upsert the version
  let updated = if $has_workspace_version {
    $cargo_toml | upsert workspace.package.version $version
  } else {
    $cargo_toml | upsert package.version $version
  }

  # Save the updated Cargo.toml
  try {
    $updated | to toml | save --force $cargo_toml_path
  } catch {|err|
    $"Failed to save Cargo.toml: ($err.msg)" | ci log error
    return {status: "error" error: $"Failed to save Cargo.toml: ($err.msg)"}
  }

  $"Updated version to ($version) in Cargo.toml" | ci log info

  # Run cargo check to update Cargo.lock
  try {
    cargo check
    "Cargo.lock updated" | ci log info
  } catch {|err|
    $"cargo check failed: ($err.msg)" | ci log error
    return {status: "error" error: $"cargo check failed: ($err.msg)"}
  }

  mut modified_files = ["Cargo.toml" "Cargo.lock"]

  # Bump excluded crates that have their own standalone package.version
  # (e.g. WASM crates excluded from the workspace). These have their own
  # Cargo.toml and Cargo.lock that must stay in sync with the release version.
  let crate_tomls = (glob crates/*/Cargo.toml)
  for crate_toml_path in $crate_tomls {
    # Normalize to a relative path so the returned list matches the root
    # files ("Cargo.toml", "Cargo.lock") and stages cleanly in git.
    let rel_path = ($crate_toml_path | path relative-to (pwd))
    let crate_toml = try {
      open $crate_toml_path
    } catch {
      continue
    }

    # Skip crates that inherit version from the workspace
    # (version.workspace = true parses to a record {workspace: true})
    let version_field = ($crate_toml | get -o package.version? | default null)
    let uses_workspace = ($version_field | describe | str starts-with "record")
    let has_standalone_version = ($version_field | is-not-empty) and not $uses_workspace

    if $has_standalone_version {
      # Bump the version in the excluded crate's Cargo.toml
      let updated_crate = ($crate_toml | upsert package.version $version)
      try {
        $updated_crate | to toml | save --force $crate_toml_path
        $"Updated version to ($version) in ($rel_path)" | ci log info
        $modified_files = ($modified_files | append $rel_path)
      } catch {|err|
        $"Failed to save ($rel_path): ($err.msg)" | ci log error
        return {status: "error" error: $"Failed to save ($rel_path): ($err.msg)"}
      }

      # Refresh the excluded crate's Cargo.lock if present. Use `cargo update -p
      # <crate>` to update ONLY the crate's own lock entry — bare `cargo update`
      # would bump all dependencies to newer versions. `-p` only resolves the
      # named crate's version change and does not compile, so it works without
      # the WASM target installed.
      let lock_path = ($crate_toml_path | path dirname | path join "Cargo.lock")
      if ($lock_path | path exists) {
        let crate_name = ($crate_toml | get -o package.name? | default "")
        try {
          cargo update -p $crate_name --manifest-path $crate_toml_path
          $"Updated Cargo.lock for ($rel_path)" | ci log info
          $modified_files = ($modified_files | append ($lock_path | path relative-to (pwd)))
        } catch {|err|
          $"cargo update failed for ($rel_path): ($err.msg)" | ci log error
          return {status: "error" error: $"cargo update failed for ($rel_path): ($err.msg)"}
        }
      }
    }
  }

  $modified_files
}
