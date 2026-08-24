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

  ["Cargo.toml" "Cargo.lock"]
}
