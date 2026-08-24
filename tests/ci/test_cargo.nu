# Test ci/cargo.nu with mocked cargo commands
# Focus: Test version update in Cargo.toml

use std/assert
use ../../modules/nu-mimic *
use test_wrappers.nu * # Import wrapped commands FIRST
use ../../modules/ci/cargo.nu * # Then import module under test

# Test 1: Update workspace.package.version
export def --env "test ci cargo update workspace version" [] {
  let temp_dir = (mktemp -d)
  let original_dir = (pwd)

  try {
    let cargo_toml = "[workspace]\nmembers = [\"crates/*\"]\n\n[workspace.package]\nversion = \"0.1.0\"\nedition = \"2021\"\n"
    $cargo_toml | save ($temp_dir | path join "Cargo.toml")

    cd $temp_dir
    mimic reset
    mimic register cargo {
      args: ['check']
      returns: ""
    }

    let result = (ci cargo update-version "0.2.0")
    cd $original_dir

    let updated = (open ($temp_dir | path join "Cargo.toml") --raw)
    assert ($updated =~ "version = \"0.2.0\"") $"Expected version updated in Cargo.toml"
    assert (($result | length) == 2) $"Expected 2 files"
    assert ("Cargo.toml" in $result) $"Expected Cargo.toml"
    assert ("Cargo.lock" in $result) $"Expected Cargo.lock"

    mimic verify
  } finally {
    cd $original_dir
    rm -rf $temp_dir
  }
}

# Test 2: update package.version (single crate)
export def --env "test ci cargo update package version" [] {
  let temp_dir = (mktemp -d)
  let original_dir = (pwd)

  try {
    let cargo_toml = "[package]\nname = \"mypkg\"\nversion = \"0.1.0\"\nedition = \"2021\"\n"
    $cargo_toml | save ($temp_dir | path join "Cargo.toml")

    cd $temp_dir
    mimic reset
    mimic register cargo {
      args: ['check']
      returns: ""
    }

    let result = (ci cargo update-version "0.2.0")
    cd $original_dir

    let updated = (open ($temp_dir | path join "Cargo.toml") --raw)
    assert ($updated =~ "version = \"0.2.0\"") $"Expected version updated"
    assert (($result | length) == 2) $"Expected 2 files"

    mimic verify
  } finally {
    cd $original_dir
    rm -rf $temp_dir
  }
}

# Test 3: cargo check failure returns error
export def --env "test ci cargo update check failure" [] {
  let temp_dir = (mktemp -d)
  let original_dir = (pwd)

  try {
    let cargo_toml = "[package]\nname = \"mypkg\"\nversion = \"0.1.0\"\n"
    $cargo_toml | save ($temp_dir | path join "Cargo.toml")

    cd $temp_dir
    mimic reset
    mimic register cargo {
      args: ['check']
      returns: "error: check failed"
      exit_code: 1
    }

    let result = (ci cargo update-version "0.2.0")
    cd $original_dir

    assert ($result.status == "error") $"Expected error status"
    assert ($result.error != null) $"Expected error message"

    mimic verify
  } finally {
    cd $original_dir
    rm -rf $temp_dir
  }
}

# Test 4: No version found in Cargo.toml
export def --env "test ci cargo update no version" [] {
  let temp_dir = (mktemp -d)
  let original_dir = (pwd)

  try {
    let cargo_toml = "[package]\nname = \"mypkg\"\n"
    $cargo_toml | save ($temp_dir | path join "Cargo.toml")

    cd $temp_dir
    let result = (ci cargo update-version "0.2.0")
    cd $original_dir

    assert ($result.status == "error") $"Expected error status"
    assert ($result.error == "No package.version or workspace.package.version found in Cargo.toml") $"Expected error message"
  } finally {
    cd $original_dir
    rm -rf $temp_dir
  }
}
