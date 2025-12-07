# Test ci/nix.nu with pipeline-oriented API
# Focus: Test flake operations with stdin/table outputs and cache management

use std/assert
use ../mocks.nu *
use ../../modules/ci/nix.nu *

# ============================================================================
# CHECK TESTS
# ============================================================================

# Test 1: Check single flake (default)
export def "test ci nix check single flake" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_check_--no-update-lock-file": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix check | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 result but got: ($result | length)"
    assert ($result.0.flake == ".") $"Expected flake '.' but got: ($result.0.flake)"
    assert ($result.0.status == "success") $"Expected success but got: ($result.0.status)"
  }
}

# ============================================================================
# CLOSURE TESTS
# ============================================================================

# Test 13: Get closure of single path
export def "test ci nix closure single path" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_path-info_--recursive__nix_store_abc-pkg": ({output: "/nix/store/abc-pkg\n/nix/store/dep1\n/nix/store/dep2" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
'/nix/store/abc-pkg' | ci nix closure | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 3) $"Expected 3 paths in closure"
    assert ($result.0 == "/nix/store/abc-pkg") $"Expected abc-pkg"
    assert ($result.1 == "/nix/store/dep1") $"Expected dep1"
    assert ($result.2 == "/nix/store/dep2") $"Expected dep2"
  }
}

# Test 14: Get closure of multiple paths
export def "test ci nix closure multiple paths" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_path-info_--recursive__nix_store_abc-pkg": ({output: "/nix/store/abc-pkg\n/nix/store/dep1" exit_code: 0} | to json)
    "MOCK_nix_path-info_--recursive__nix_store_xyz-pkg": ({output: "/nix/store/xyz-pkg\n/nix/store/dep2" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['/nix/store/abc-pkg' '/nix/store/xyz-pkg'] | ci nix closure | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 4) $"Expected 4 paths in closure"
    assert ("/nix/store/abc-pkg" in $result) $"Expected abc-pkg in closure"
    assert ("/nix/store/xyz-pkg" in $result) $"Expected xyz-pkg in closure"
    assert ("/nix/store/dep1" in $result) $"Expected dep1 in closure"
    assert ("/nix/store/dep2" in $result) $"Expected dep2 in closure"
  }
}

# Test 15: Get closure with empty input
export def "test ci nix closure empty input" [] {
  with-env {
    NU_TEST_MODE: "true"
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
[] | ci nix closure | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 0) $"Expected empty result"
  }
}

# ============================================================================
# CACHE TESTS
# ============================================================================

# Test 16: Push single path to cache
export def "test ci nix cache push single path" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_path-info__nix_store_abc-pkg": ({output: "/nix/store/abc-pkg" exit_code: 0} | to json)
    "MOCK_cachix_push_cachix__nix_store_abc-pkg": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['/nix/store/abc-pkg'] | ci nix cache cachix | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 result"
    assert ($result.0.status == "success") $"Expected success"
    assert ($result.0.cache == "cachix") $"Expected cachix cache"
  }
}

# Test 14: Push multiple paths to cache
export def "test ci nix cache push multiple paths" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_path-info__nix_store_abc": ({output: "/nix/store/abc" exit_code: 0} | to json)
    "MOCK_nix_path-info__nix_store_def": ({output: "/nix/store/def" exit_code: 0} | to json)
    "MOCK_nix_copy_--to_s3:__bucket__nix_store_abc": ({output: "" exit_code: 0} | to json)
    "MOCK_nix_copy_--to_s3:__bucket__nix_store_def": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['/nix/store/abc' '/nix/store/def'] | ci nix cache 's3://bucket' | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 results"
    assert ($result.0.status == "success") $"Expected success for path 0"
    assert ($result.1.status == "success") $"Expected success for path 1"
  }
}

# Test 15: Pipeline - build and push to cache
export def "test ci nix build and push pipeline" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_eval_--impure_--expr_builtins.currentSystem": ({output: "\"x86_64-linux\"" exit_code: 0} | to json)
    "MOCK_nix_build_.#pkg1_--print-out-paths_--no-update-lock-file": ({output: "/nix/store/abc-pkg1" exit_code: 0} | to json)
    "MOCK_nix_path-info__nix_store_abc-pkg1": ({output: "/nix/store/abc-pkg1" exit_code: 0} | to json)
    "MOCK_cachix_push_cachix__nix_store_abc-pkg1": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix build pkg1 | where status == 'success' | get path | ci nix cache cachix | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 push result"
    assert ($result.0.path == "/nix/store/abc-pkg1") $"Expected correct path"
  }
}

# Test 16: Check upstream cache (path cached)
export def "test ci nix cache check upstream cached" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_path-info__nix_store_abc-pkg": ({output: "/nix/store/abc-pkg" exit_code: 0} | to json)
    "MOCK_nix_path-info_--store_https:__cache.nixos.org__nix_store_abc-pkg": ({output: "/nix/store/abc-pkg" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['/nix/store/abc-pkg'] | ci nix cache 'https://cache.nixos.org' --upstream 'https://cache.nixos.org' --dry-run | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 result"
    assert ($result.0.cached == true) $"Expected path to be cached"
    assert ($result.0.upstream == "https://cache.nixos.org") $"Expected upstream to be set"
    assert ($result.0.cache == null) $"Expected no cache push in dry-run"
  }
}

# Test 17: Check upstream cache (path not cached)
export def "test ci nix cache check upstream not cached" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_path-info__nix_store_xyz-pkg": ({output: "/nix/store/xyz-pkg" exit_code: 0} | to json)
    "MOCK_nix_path-info_--store_https:__cache.nixos.org__nix_store_xyz-pkg": ({output: "" exit_code: 1} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['/nix/store/xyz-pkg'] | ci nix cache 'https://cache.nixos.org' --upstream 'https://cache.nixos.org' --dry-run | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 result"
    assert ($result.0.cached == false) $"Expected path to not be cached"
    assert ($result.0.upstream == "https://cache.nixos.org") $"Expected upstream to be set"
  }
}

# Test 18: Check upstream and push to target cache (path not in upstream)
export def "test ci nix cache check and push" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_path-info__nix_store_abc-pkg": ({output: "/nix/store/abc-pkg" exit_code: 0} | to json)
    "MOCK_nix_path-info_--store_https:__cache.nixos.org__nix_store_abc-pkg": ({output: "" exit_code: 1} | to json)
    "MOCK_cachix_push_cachix__nix_store_abc-pkg": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['/nix/store/abc-pkg'] | ci nix cache cachix --upstream 'https://cache.nixos.org' | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 result"
    assert ($result.0.cached == false) $"Expected path not in upstream"
    assert ($result.0.upstream == "https://cache.nixos.org") $"Expected upstream checked"
    assert ($result.0.cache == "cachix") $"Expected push to cachix"
    assert ($result.0.status == "success") $"Expected successful push"
  }
}

# Test 19: Check upstream and skip push when already cached
export def "test ci nix cache skip when upstream cached" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_path-info__nix_store_xyz-pkg": ({output: "/nix/store/xyz-pkg" exit_code: 0} | to json)
    "MOCK_nix_path-info_--store_https:__cache.nixos.org__nix_store_xyz-pkg": ({output: "/nix/store/xyz-pkg" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['/nix/store/xyz-pkg'] | ci nix cache cachix --upstream 'https://cache.nixos.org' | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 result"
    assert ($result.0.cached == true) $"Expected path in upstream"
    assert ($result.0.upstream == "https://cache.nixos.org") $"Expected upstream checked"
    assert ($result.0.cache == "cachix") $"Expected cache target set"
    assert ($result.0.status == "skipped") $"Expected skipped status for cached path"
  }
}

# Test 20: Dry-run status should be "dry-run" not "success"
export def "test ci nix cache dry-run status" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_path-info__nix_store_abc-pkg": ({output: "/nix/store/abc-pkg" exit_code: 0} | to json)
    "MOCK_nix_path-info_--store_https:__cache.nixos.org__nix_store_abc-pkg": ({output: "" exit_code: 1} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['/nix/store/abc-pkg'] | ci nix cache cachix --upstream 'https://cache.nixos.org' --dry-run | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 result"
    assert ($result.0.status == "dry-run") $"Expected dry-run status, not success"
    assert ($result.0.cache == null) $"Expected no cache in dry-run"
  }
}

# ============================================================================
# IMPURE AND ARGS FLAGS TESTS
# ============================================================================

# Test 21: Check with --impure flag
export def "test ci nix check with impure" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_check_--impure_--no-update-lock-file": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix check --impure | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.0.status == "success") $"Expected success with --impure"
  }
}

# Test 22: Check with --args
export def "test ci nix check with args" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_check_--verbose_--option_cores_4_--no-update-lock-file": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix check --args '--verbose --option cores 4' | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.0.status == "success") $"Expected success with --args"
  }
}

# Test 23: Build with --impure flag
export def "test ci nix build with impure" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_eval_--impure_--expr_builtins.currentSystem": ({output: "\"x86_64-linux\"" exit_code: 0} | to json)
    "MOCK_nix_build_.#mypackage_--print-out-paths_--no-update-lock-file_--impure": ({output: "/nix/store/xyz-mypackage" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix build mypackage --impure | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.0.status == "success") $"Expected success with --impure"
    assert ($result.0.path == "/nix/store/xyz-mypackage") $"Expected store path"
  }
}

# Test 24: Build with --args
export def "test ci nix build with args" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_eval_--impure_--expr_builtins.currentSystem": ({output: "\"x86_64-linux\"" exit_code: 0} | to json)
    "MOCK_nix_build_.#mypackage_--print-out-paths_--no-update-lock-file_--option_cores_8": ({output: "/nix/store/xyz-mypackage" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix build mypackage --args '--option cores 8' | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.0.status == "success") $"Expected success with --args"
  }
}

# ============================================================================
# FLAKES TESTS
# ============================================================================

# Test 25: Filter flakes - find only flake directories
export def "test ci nix flakes filters correctly" [] {
  # Create temp directories
  let temp_dir = (mktemp -d)
  let flake1 = ($temp_dir | path join "flake1")
  let flake2 = ($temp_dir | path join "flake2")
  let not_flake = ($temp_dir | path join "not_flake")

  mkdir $flake1
  mkdir $flake2
  mkdir $not_flake

  # Create flake.nix in flake directories
  touch ($flake1 | path join "flake.nix")
  touch ($flake2 | path join "flake.nix")

  try {
    let test_script = $"
use modules/ci/nix.nu *
['($flake1)' '($flake2)' '($not_flake)'] | ci nix flakes | to json"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 flakes but got: ($result | length)"
    assert ($flake1 in $result) $"Expected ($flake1) in results"
    assert ($flake2 in $result) $"Expected ($flake2) in results"
    assert ($not_flake not-in $result) $"Did not expect ($not_flake) in results"
  }

  # Cleanup
  rm -rf $temp_dir
}

# Test 26: Filter flakes - empty list
export def "test ci nix flakes empty input" [] {
  let test_script = "
use modules/ci/nix.nu *
[] | ci nix flakes | to json
"
  let output = (nu -c $test_script)
  let result = ($output | from json)

  assert (($result | length) == 0) $"Expected 0 flakes but got: ($result | length)"
}

# Test 27: Filter flakes - all non-flakes
export def "test ci nix flakes all non-flakes" [] {
  let temp_dir = (mktemp -d)
  let dir1 = ($temp_dir | path join "dir1")
  let dir2 = ($temp_dir | path join "dir2")

  mkdir $dir1
  mkdir $dir2

  try {
    let test_script = $"
use modules/ci/nix.nu *
['($dir1)' '($dir2)'] | ci nix flakes | to json"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 0) $"Expected 0 flakes but got: ($result | length)"
  }

  # Cleanup
  rm -rf $temp_dir
}

# Test 28: Filter flakes - file paths are filtered out
export def "test ci nix flakes filters out file paths" [] {
  let temp_dir = (mktemp -d)
  let flake1 = ($temp_dir | path join "flake1")

  mkdir $flake1
  touch ($flake1 | path join "flake.nix")

  try {
    # File paths should be filtered out, only directories returned
    let flake1_file = ($flake1 | path join "flake.nix")

    let test_script = $"
use modules/ci/nix.nu *
['($flake1)' '($flake1_file)'] | ci nix flakes | to json"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 flake (file paths filtered out) but got: ($result | length)"
    assert ($flake1 in $result) $"Expected directory ($flake1) in results"
  }

  # Cleanup
  rm -rf $temp_dir
}

# Test 29: Filter flakes - mixed files, dirs, flakes, non-flakes
export def "test ci nix flakes mixed everything" [] {
  let temp_dir = (mktemp -d)
  let flake_dir = ($temp_dir | path join "flake_dir")
  let non_flake_dir = ($temp_dir | path join "non_flake_dir")
  let some_file = ($temp_dir | path join "file.txt")

  mkdir $flake_dir
  mkdir $non_flake_dir
  touch ($flake_dir | path join "flake.nix")
  touch $some_file

  try {
    let test_script = $"
use modules/ci/nix.nu *
['($flake_dir)' '($non_flake_dir)' '($some_file)' '/nonexistent/path'] | ci nix flakes | to json"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 flake but got: ($result | length)"
    assert ($flake_dir in $result) $"Expected ($flake_dir) in results"
  }

  # Cleanup
  rm -rf $temp_dir
}
