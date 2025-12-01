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
    "MOCK_nix_flake_check": ({output: "" exit_code: 0} | to json)
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

# Test 2: Check multiple flakes from pipeline
export def "test ci nix check multiple flakes" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_check": ({output: "" exit_code: 0} | to json)
    "MOCK_nix_flake_check_--flake_.._backend": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['.' '../backend'] | ci nix check | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 results but got: ($result | length)"
    assert ($result.0.status == "success") $"Expected success for flake 0"
    assert ($result.1.status == "success") $"Expected success for flake 1"
  }
}

# Test 3: Check with failure
export def "test ci nix check with failure" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_check": ({output: "error: some issue" exit_code: 1} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix check | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.0.status == "failed") $"Expected failed status"
    assert ($result.0.error != null) $"Expected error message"
  }
}

# ============================================================================
# UPDATE TESTS
# ============================================================================

# Test 4: Update all inputs in single flake
export def "test ci nix update all inputs" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_update": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix update | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.0.status == "success") $"Expected success"
    assert ($result.0.input == "all") $"Expected 'all' inputs"
  }
}

# Test 5: Update specific input
export def "test ci nix update specific input" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_update_nixpkgs": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix update nixpkgs | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.0.status == "success") $"Expected success"
    assert ($result.0.input == "nixpkgs") $"Expected nixpkgs input"
  }
}

# Test 6: Update multiple flakes
export def "test ci nix update multiple flakes" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_update": ({output: "" exit_code: 0} | to json)
    "MOCK_nix_flake_update_--flake_.._backend": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['.' '../backend'] | ci nix update | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 results"
  }
}

# ============================================================================
# PACKAGES TESTS
# ============================================================================

# Test 7: List packages from single flake
export def "test ci nix packages single flake" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_show_--json": ({output: '{"packages":{"x86_64-linux":{"pkg1":{},"pkg2":{}}}}' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix packages | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 packages"
    assert ($result.0.name == "pkg1" or $result.0.name == "pkg2") $"Expected pkg1 or pkg2"
    assert ($result.0.system == "x86_64-linux") $"Expected x86_64-linux system"
  }
}

# Test 8: List packages from multiple flakes
export def "test ci nix packages multiple flakes" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_show_--json": ({output: '{"packages":{"x86_64-linux":{"pkg1":{}}}}' exit_code: 0} | to json)
    "MOCK_nix_flake_show_--flake_.._backend_--json": ({output: '{"packages":{"x86_64-linux":{"pkg2":{}}}}' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['.' '../backend'] | ci nix packages | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 packages total"
  }
}

# ============================================================================
# BUILD TESTS
# ============================================================================

# Test 9: Build all packages
export def "test ci nix build all packages" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_show_--json": ({output: '{"packages":{"x86_64-linux":{"pkg1":{},"pkg2":{}}}}' exit_code: 0} | to json)
    "MOCK_nix_build_.#pkg1_--print-out-paths_--no-link": ({output: "/nix/store/abc-pkg1" exit_code: 0} | to json)
    "MOCK_nix_build_.#pkg2_--print-out-paths_--no-link": ({output: "/nix/store/def-pkg2" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix build | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 build results"
    assert ($result.0.status == "success") $"Expected success for pkg1"
    assert ($result.1.status == "success") $"Expected success for pkg2"
    assert ($result.0.path == "/nix/store/abc-pkg1" or $result.0.path == "/nix/store/def-pkg2") $"Expected store path"
  }
}

# Test 10: Build specific package with -p flag
export def "test ci nix build specific package" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_build_.#mypackage_--print-out-paths_--no-link": ({output: "/nix/store/xyz-mypackage" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix build mypackage | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 build result"
    assert ($result.0.package == "mypackage") $"Expected mypackage"
    assert ($result.0.path == "/nix/store/xyz-mypackage") $"Expected store path"
  }
}

# Test 11: Build multiple specific packages
export def "test ci nix build multiple packages" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_build_.#pkg1_--print-out-paths_--no-link": ({output: "/nix/store/abc-pkg1" exit_code: 0} | to json)
    "MOCK_nix_build_.#pkg2_--print-out-paths_--no-link": ({output: "/nix/store/def-pkg2" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix build pkg1 pkg2 | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 build results"
  }
}

# Test 12: Build from multiple flakes
export def "test ci nix build multiple flakes" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_build_.#pkg1_--print-out-paths_--no-link": ({output: "/nix/store/abc-pkg1" exit_code: 0} | to json)
    "MOCK_nix_build_.._backend#pkg2_--print-out-paths_--no-link": ({output: "/nix/store/def-pkg2" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['.' '../backend'] | ci nix build pkg1 pkg2 | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 4) $"Expected 4 build results, 2 per flake"
  }
}

# ============================================================================
# CACHE PUSH TESTS
# ============================================================================

# Test 13: Push single path to cache
export def "test ci nix cache push single path" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_copy_--to_cachix__nix_store_abc-pkg": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['/nix/store/abc-pkg'] | ci nix cache --cache cachix | to json
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
    "MOCK_nix_copy_--to_s3:__bucket__nix_store_abc": ({output: "" exit_code: 0} | to json)
    "MOCK_nix_copy_--to_s3:__bucket__nix_store_def": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
['/nix/store/abc' '/nix/store/def'] | ci nix cache --cache 's3://bucket' | to json
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
    "MOCK_nix_build_.#pkg1_--print-out-paths_--no-link": ({output: "/nix/store/abc-pkg1" exit_code: 0} | to json)
    "MOCK_nix_copy_--to_cachix__nix_store_abc-pkg1": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix build pkg1 | where status == 'success' | get path | ci nix cache --cache cachix | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 push result"
    assert ($result.0.path == "/nix/store/abc-pkg1") $"Expected correct path"
  }
}

# ============================================================================
# IMPURE AND ARGS FLAGS TESTS
# ============================================================================

# Test 16: Check with --impure flag
export def "test ci nix check with impure" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_check_--impure": ({output: "" exit_code: 0} | to json)
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

# Test 17: Check with --args
export def "test ci nix check with args" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_check_--verbose_--option_cores_4": ({output: "" exit_code: 0} | to json)
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

# Test 18: Build with --impure flag
export def "test ci nix build with impure" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_build_.#mypackage_--print-out-paths_--no-link_--impure": ({output: "/nix/store/xyz-mypackage" exit_code: 0} | to json)
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

# Test 19: Build with --args
export def "test ci nix build with args" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_build_.#mypackage_--print-out-paths_--no-link_--option_cores_8": ({output: "/nix/store/xyz-mypackage" exit_code: 0} | to json)
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

# Test 20: Filter flakes - find only flake directories
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

# Test 21: Filter flakes - empty list
export def "test ci nix flakes empty input" [] {
  let test_script = "
use modules/ci/nix.nu *
[] | ci nix flakes | to json
"
  let output = (nu -c $test_script)
  let result = ($output | from json)

  assert (($result | length) == 0) $"Expected 0 flakes but got: ($result | length)"
}

# Test 22: Filter flakes - all non-flakes
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

# Test 23: Filter flakes - file paths are filtered out
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

# Test 24: Filter flakes - mixed files, dirs, flakes, non-flakes
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
