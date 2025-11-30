# Test ci/nix.nu with mocked nix commands
# Focus: Test flake operations and cache management

use std/assert
use ../mocks.nu *
use ../../modules/ci/nix.nu *

# ============================================================================
# FLAKE CHECK TESTS
# ============================================================================

# Test 1: Flake check success
export def "test ci nix flake check success" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_check": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix flake check
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "Flake check passed") $"Expected success message but got: ($output)"
  }
}

# Test 2: Flake check with custom path
export def "test ci nix flake check custom path" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_check_--flake_.._myflake": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix flake check --flake '../myflake'
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "Flake check passed") $"Expected success but got: ($output)"
  }
}

# ============================================================================
# FLAKE UPDATE TESTS
# ============================================================================

# Test 3: Update all inputs
export def "test ci nix flake update all" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_update": ({output: "Updated inputs" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix flake update
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "Updated") $"Expected update message but got: ($output)"
  }
}

# Test 4: Update specific input
export def "test ci nix flake update specific input" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_update_nixpkgs": ({output: "Updated nixpkgs" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix flake update nixpkgs
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "nixpkgs") $"Expected nixpkgs update but got: ($output)"
  }
}

# ============================================================================
# FLAKE SHOW TESTS
# ============================================================================

# Test 5: Show flake outputs
export def "test ci nix flake show" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_show_--json": ({output: '{"packages":{"x86_64-linux":{"default":{"type":"derivation"}}}}' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix flake show
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "packages") $"Expected packages output but got: ($output)"
  }
}

# ============================================================================
# BUILD TESTS
# ============================================================================

# Test 6: Build all packages
export def "test ci nix flake build all packages" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_show_--json": ({output: '{"packages":{"x86_64-linux":{"pkg1":{},"pkg2":{}}}}' exit_code: 0} | to json)
    "MOCK_nix_build_.#pkg1_--print-out-paths_--no-link": ({output: "/nix/store/abc-pkg1" exit_code: 0} | to json)
    "MOCK_nix_build_.#pkg2_--print-out-paths_--no-link": ({output: "/nix/store/def-pkg2" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix flake build
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "pkg1") $"Expected pkg1 but got: ($output)"
    assert ($output | str contains "pkg2") $"Expected pkg2 but got: ($output)"
    assert ($output | str contains "/nix/store") $"Expected store paths but got: ($output)"
  }
}

# Test 7: Build specific package
export def "test ci nix flake build specific package" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_build_.#mypackage_--print-out-paths_--no-link": ({output: "/nix/store/xyz-mypackage" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix flake build mypackage
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "mypackage") $"Expected mypackage but got: ($output)"
    assert ($output | str contains "/nix/store/xyz-mypackage") $"Expected store path but got: ($output)"
  }
}

# ============================================================================
# CACHE PUSH TESTS
# ============================================================================

# Test 8: Push to cache
export def "test ci nix cache push" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_copy_--to_s3:__mybucket__nix_store_abc-pkg": ({output: "Copying to cache" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix cache push '/nix/store/abc-pkg' --cache 's3://mybucket'
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "Pushed") $"Expected push confirmation but got: ($output)"
  }
}

# Test 9: Push multiple paths to cache
export def "test ci nix cache push multiple paths" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_copy_--to_s3:__cache__nix_store_abc__nix_store_def": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix cache push '/nix/store/abc' '/nix/store/def' --cache 's3://cache'
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "Pushed 2") $"Expected 2 paths pushed but got: ($output)"
  }
}

# ============================================================================
# LIST PACKAGES TESTS
# ============================================================================

# Test 10: List all buildable packages
export def "test ci nix flake list packages" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_nix_flake_show_--json": ({output: '{"packages":{"x86_64-linux":{"default":{},"pkg1":{},"pkg2":{}},"aarch64-darwin":{"default":{},"pkg1":{}}}}' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/nix.nu *
ci nix flake list-packages
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "pkg1") $"Expected pkg1 but got: ($output)"
    assert ($output | str contains "pkg2") $"Expected pkg2 but got: ($output)"
  }
}
