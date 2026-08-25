# Test ci/artifacts.nu

use std/assert
use ../../modules/nu-mimic *
use test_wrappers.nu *
use ../../modules/ci/artifacts.nu *

# Test 1: Generate platform data for one architecture
export def --env "test ci artifacts platform-data single" [] {
  let temp_dir = (mktemp -d)
  let original_dir = (pwd)

  try {
    mkdir ($temp_dir | path join "artifacts")
    touch ($temp_dir | path join "artifacts/context-0.1.0-x86_64-linux.tgz")
    "abc123def456" | save ($temp_dir | path join "artifacts/context-0.1.0-x86_64-linux-nix.sha256")

    cd $temp_dir
    with-env {GITHUB_REPOSITORY: "owner/repo"} {
      let result = (ci artifacts platform-data "0.1.0" "artifacts" "context")
      assert (($result | length) == 1) $"Expected 1 file, got ($result | length)"
    }
    cd $original_dir

    let data = (open --raw ($temp_dir | path join "data/x86_64-linux.json"))
    assert ($data =~ "owner/repo") $"Expected repo in url"
    assert ($data =~ "abc123def456") $"Expected hash"
    assert ($data =~ "x86_64-linux.tgz") $"Expected filename in url"
  } finally {
    cd $original_dir
    rm -rf $temp_dir
  }
}

# Test 2: Multiple architectures
export def --env "test ci artifacts platform data multiple" [] {
  let temp_dir = (mktemp -d)
  let original_dir = (pwd)

  try {
    mkdir ($temp_dir | path join "artifacts")
    for arch in [x86_64-linux aarch64-darwin x86_64-darwin] {
      touch ($temp_dir | path join $"artifacts/context-0.1.0-($arch).tgz")
      $"hash-($arch)" | save ($temp_dir | path join $"artifacts/context-0.1.0-($arch)-nix.sha256")
    }

    cd $temp_dir
    with-env {GITHUB_REPOSITORY: "owner/repo"} {
      let result = (ci artifacts platform-data "0.1.0" "artifacts" "context")
      assert (($result | length) == 3) $"Expected 3 data files"
    }
    cd $original_dir

    assert (($temp_dir | path join "data/x86_64-linux.json" | path exists)) $"Expected linux data"
    assert (($temp_dir | path join "data/aarch64-darwin.json" | path exists)) $"Expected darwin data"
  } finally {
    cd $original_dir
    rm -rf $temp_dir
  }
}

# Test: custom archive_ext
export def "test ci artifacts platform data custom ext" [] {
  let temp_dir = (mktemp -d)
  let original_dir = (pwd)

  try {
    mkdir ($temp_dir | path join "artifacts")
    touch ($temp_dir | path join "artifacts/context-0.1.0-x86_64-linux.tar.gz")
    "abc" | save ($temp_dir | path join "artifacts/context-0.1.0-x86_64-linux-nix.sha256")

    cd $temp_dir
    with-env {GITHUB_REPOSITORY: "owner/repo"} {
      let result = (ci artifacts platform-data "0.1.0" "artifacts" "context" --archive-ext ".tar.gz")
      assert (($result | length) == 1) $"Expected 1 data file"
    }
    cd $original_dir

    assert (($temp_dir | path join "data/x86_64-linux.json" | path exists)) $"Expected linux data"
  } finally {
    cd $original_dir
    rm -rf $temp_dir
  }
}

# Test: missing hash file skips
export def "test ci artifacts platform data missing hash" [] {
  let temp_dir = (mktemp -d)
  let original_dir = (pwd)

  try {
    mkdir ($temp_dir | path join "artifacts")
    touch ($temp_dir | path join "artifacts/context-0.1.0-x86_64-linux.tgz")

    cd $temp_dir
    with-env {GITHUB_REPOSITORY: "owner/repo"} {
      let result = (ci artifacts platform-data "0.1.0" "artifacts" "context")
      assert (($result | length) == 0) $"Expected no data files"
    }
    cd $original_dir

    assert (not ($temp_dir | path join "data/x86_64-linux.json" | path exists)) $"Expected no linux data"
  } finally {
    cd $original_dir
    rm -rf $temp_dir
  }
}

# Test: platform-data with --tag uses suffixed tag in URL
export def --env "test ci artifacts platform data with tag" [] {
  let temp_dir = (mktemp -d)
  let original_dir = (pwd)

  try {
    mkdir ($temp_dir | path join "artifacts")
    touch ($temp_dir | path join "artifacts/context-0.1.0-x86_64-linux.tgz")
    "abc123def456" | save ($temp_dir | path join "artifacts/context-0.1.0-x86_64-linux-nix.sha256")

    cd $temp_dir
    with-env {GITHUB_REPOSITORY: "owner/repo"} {
      let result = (ci artifacts platform-data "0.1.0" "artifacts" "context" --tag "v0.1.0-abc1234")
      assert (($result | length) == 1) $"Expected 1 file"
    }
    cd $original_dir

    let data = (open --raw ($temp_dir | path join "data/x86_64-linux.json"))
    assert ($data =~ "v0.1.0-abc1234") $"Expected suffixed tag in url"
    assert (not ($data =~ "releases/download/v0.1.0/")) $"Expected no plain v0.1.0 tag in url"
  } finally {
    cd $original_dir
    rm -rf $temp_dir
  }
}
