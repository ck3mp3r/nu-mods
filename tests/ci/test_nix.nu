# Test ci/nix.nu with pipeline-oriented API
# Focus: Test flake operations with stdin/table outputs and cache management

use std/assert
use ../../modules/nu-mimic *
use test_wrappers.nu * # Import wrapped commands FIRST
use ../../modules/ci/nix.nu * # Then import module under test

# ============================================================================
# CHECK TESTS
# ============================================================================

# Test 1: Check single flake (default)
export def --env "test ci nix check single flake" [] {
  mimic reset

  # Setup expectations
  mimic register nix {
    args: ['flake' 'check' '--no-update-lock-file']
    returns: ''
  }

  # Run test
  let result = (ci nix check)

  assert (($result | length) == 1) $"Expected 1 result but got: ($result | length)"
  assert ($result.0.flake == ".") $"Expected flake '.' but got: ($result.0.flake)"
  assert ($result.0.status == "success") $"Expected success but got: ($result.0.status)"

  mimic verify
}

# ============================================================================
# PACKAGES TESTS
# ============================================================================

# Test 2: List packages with new v2 format
export def --env "test ci nix packages v2 format" [] {
  mimic reset

  # Mock nix flake show with new v2 format (inventory structure)
  mimic register nix {
    args: ['flake' 'show' '--json' '--no-update-lock-file']
    returns: (
      {
        version: 2
        inventory: {
          packages: {
            doc: "Packages"
            output: {
              children: {
                "x86_64-linux": {
                  children: {
                    pkg1: {what: "package"}
                    pkg2: {what: "package"}
                  }
                }
                "aarch64-darwin": {
                  children: {
                    pkg1: {what: "package"}
                  }
                }
                "aarch64-linux": {
                  filtered: true
                }
              }
            }
          }
        }
      } | to json
    )
  }

  let result = (ci nix packages)

  assert (($result | length) == 3) $"Expected 3 packages but got: ($result | length)"

  # Check x86_64-linux packages
  let x86_pkgs = ($result | where system == "x86_64-linux")
  assert (($x86_pkgs | length) == 2) $"Expected 2 x86_64-linux packages"
  assert ("pkg1" in ($x86_pkgs | get name)) $"Expected pkg1 in x86_64-linux"
  assert ("pkg2" in ($x86_pkgs | get name)) $"Expected pkg2 in x86_64-linux"

  # Check aarch64-darwin packages
  let darwin_pkgs = ($result | where system == "aarch64-darwin")
  assert (($darwin_pkgs | length) == 1) $"Expected 1 aarch64-darwin package"
  assert ($darwin_pkgs.0.name == "pkg1") $"Expected pkg1 in aarch64-darwin"

  # Verify no aarch64-linux packages (filtered)
  let linux_arm_pkgs = ($result | where system == "aarch64-linux")
  assert (($linux_arm_pkgs | length) == 0) "Expected 0 aarch64-linux packages (filtered)"

  mimic verify
}

# Test 3: List packages with legacy v1 format (backward compatibility)
export def --env "test ci nix packages v1 format legacy" [] {
  mimic reset

  # Mock nix flake show with old v1 format (direct packages structure)
  mimic register nix {
    args: ['flake' 'show' '--json' '--no-update-lock-file']
    returns: (
      {
        packages: {
          "x86_64-linux": {
            pkg1: {type: "derivation"}
            pkg2: {type: "derivation"}
          }
          "aarch64-darwin": {
            pkg1: {type: "derivation"}
          }
        }
      } | to json
    )
  }

  let result = (ci nix packages)

  assert (($result | length) == 3) $"Expected 3 packages but got: ($result | length)"

  # Check x86_64-linux packages
  let x86_pkgs = ($result | where system == "x86_64-linux")
  assert (($x86_pkgs | length) == 2) $"Expected 2 x86_64-linux packages"

  # Check aarch64-darwin packages
  let darwin_pkgs = ($result | where system == "aarch64-darwin")
  assert (($darwin_pkgs | length) == 1) $"Expected 1 aarch64-darwin package"

  mimic verify
}

# Test 4: List packages with empty flake
export def --env "test ci nix packages empty flake" [] {
  mimic reset

  # Mock nix flake show with no packages
  mimic register nix {
    args: ['flake' 'show' '--json' '--no-update-lock-file']
    returns: (
      {
        version: 2
        inventory: {
          apps: {doc: "Apps" output: {children: {}}}
        }
      } | to json
    )
  }

  let result = (ci nix packages)

  assert (($result | length) == 0) $"Expected 0 packages for empty flake"

  mimic verify
}

# ============================================================================
# CLOSURE TESTS
# ============================================================================

# Test 13: Get closure of single path
export def --env "test ci nix closure single path" [] {
  mimic reset

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/abc-pkg']
    returns: "/nix/store/abc-pkg\n/nix/store/dep1\n/nix/store/dep2"
  }

  let result = ('/nix/store/abc-pkg' | ci nix closure)

  assert (($result | length) == 3) $"Expected 3 paths in closure"
  assert ($result.0 == "/nix/store/abc-pkg") $"Expected abc-pkg"
  assert ($result.1 == "/nix/store/dep1") $"Expected dep1"
  assert ($result.2 == "/nix/store/dep2") $"Expected dep2"

  mimic verify
}

# Test 14: Get closure of multiple paths
export def --env "test ci nix closure multiple paths" [] {
  mimic reset

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/abc-pkg']
    returns: "/nix/store/abc-pkg\n/nix/store/dep1"
  }

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/xyz-pkg']
    returns: "/nix/store/xyz-pkg\n/nix/store/dep2"
  }

  let result = (['/nix/store/abc-pkg' '/nix/store/xyz-pkg'] | ci nix closure)

  assert (($result | length) == 4) $"Expected 4 paths in closure"
  assert ("/nix/store/abc-pkg" in $result) $"Expected abc-pkg in closure"
  assert ("/nix/store/xyz-pkg" in $result) $"Expected xyz-pkg in closure"
  assert ("/nix/store/dep1" in $result) $"Expected dep1 in closure"
  assert ("/nix/store/dep2" in $result) $"Expected dep2 in closure"

  mimic verify
}

# Test 15: Get closure with empty input
export def --env "test ci nix closure empty input" [] {
  mimic reset

  let result = ([] | ci nix closure)

  assert (($result | length) == 0) $"Expected empty result"
}

# Test: closure unions the build closure with the runtime closure
export def --env "test ci nix closure unions build closure" [] {
  mimic reset

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/abc-pkg']
    returns: "/nix/store/abc-pkg\n/nix/store/dep1"
  }

  mimic register nix-store {
    args: ['--query' '--deriver' '/nix/store/abc-pkg']
    returns: "/nix/store/abc-pkg.drv"
  }

  mimic register nix-store {
    args: ['-qR' '--include-outputs' '/nix/store/abc-pkg.drv']
    returns: "/nix/store/abc-pkg\n/nix/store/dep1\n/nix/store/vendor\n/nix/store/toolchain\n/nix/store/abc-pkg.drv"
  }

  let result = ('/nix/store/abc-pkg' | ci nix closure)

  assert ("/nix/store/vendor" in $result) $"Expected vendor in union closure: got ($result)"
  assert ("/nix/store/toolchain" in $result) $"Expected toolchain in union closure: got ($result)"
  assert ("/nix/store/abc-pkg.drv" in $result) $"Expected the derivation in union closure: got ($result)"
  assert (($result | length) == 5) $"Expected 5 paths in union closure but got: ($result | length)"
  assert (($result | uniq | length) == ($result | length)) $"Expected unique paths only: got ($result)"

  mimic verify
}

# Test: unknown-deriver falls back to the runtime closure
export def --env "test ci nix closure unknown deriver fallback" [] {
  mimic reset

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/abc-pkg']
    returns: "/nix/store/abc-pkg\n/nix/store/dep1"
  }

  mimic register nix-store {
    args: ['--query' '--deriver' '/nix/store/abc-pkg']
    returns: "unknown-deriver"
  }

  let result = ('/nix/store/abc-pkg' | ci nix closure)

  assert (($result | length) == 2) $"Expected runtime closure only but got: ($result)"
  assert ($result == ["/nix/store/abc-pkg" "/nix/store/dep1"]) $"Expected runtime closure unchanged: got ($result)"

  mimic verify
}

# Test: overlapping runtime and build closures are deduplicated
export def --env "test ci nix closure dedups overlapping closures" [] {
  mimic reset

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/dup-pkg']
    returns: "/nix/store/dup-pkg\n/nix/store/dep1\n/nix/store/dep2"
  }

  mimic register nix-store {
    args: ['--query' '--deriver' '/nix/store/dup-pkg']
    returns: "/nix/store/dup-pkg.drv"
  }

  mimic register nix-store {
    args: ['-qR' '--include-outputs' '/nix/store/dup-pkg.drv']
    returns: "/nix/store/dup-pkg\n/nix/store/dep1\n/nix/store/dep2\n/nix/store/dep1\n/nix/store/dup-pkg.drv"
  }

  let result = ('/nix/store/dup-pkg' | ci nix closure)

  assert (($result | length) == 4) $"Expected 4 unique paths but got: ($result | length)"
  assert (($result | uniq | length) == ($result | length)) $"Expected unique paths only: got ($result)"
  assert ($result == ["/nix/store/dup-pkg" "/nix/store/dep1" "/nix/store/dep2" "/nix/store/dup-pkg.drv"]) $"Unexpected union result: got ($result)"

  mimic verify
}

# Test: multi-line mocked build closure is read back from the temp file
export def --env "test ci nix closure reads multi-line build closure" [] {
  mimic reset

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/multi-pkg']
    returns: "/nix/store/multi-pkg"
  }

  mimic register nix-store {
    args: ['--query' '--deriver' '/nix/store/multi-pkg']
    returns: "/nix/store/multi-pkg.drv"
  }

  mimic register nix-store {
    args: ['-qR' '--include-outputs' '/nix/store/multi-pkg.drv']
    returns: "/nix/store/multi-pkg\n/nix/store/vendor-a\n/nix/store/vendor-b\n/nix/store/toolchain-c\n/nix/store/crate-src-d\n/nix/store/multi-pkg.drv"
  }

  let result = ('/nix/store/multi-pkg' | ci nix closure)

  assert ("/nix/store/vendor-a" in $result) $"Expected vendor-a in closure: got ($result)"
  assert ("/nix/store/vendor-b" in $result) $"Expected vendor-b in closure: got ($result)"
  assert ("/nix/store/toolchain-c" in $result) $"Expected toolchain-c in closure: got ($result)"
  assert ("/nix/store/crate-src-d" in $result) $"Expected crate-src-d in closure: got ($result)"
  assert (($result | length) == 6) $"Expected 6 paths in closure but got: ($result | length)"

  mimic verify
}

# ============================================================================
# CACHE TESTS
# ============================================================================

# Test: Push single path to cache (one batched invocation)
export def --env "test ci nix cache push single path" [] {
  mimic reset

  mimic register cachix {
    args: ['push' 'cachix' '/nix/store/abc-pkg']
    returns: ""
    exit_code: 0
  }

  let result = (['/nix/store/abc-pkg'] | ci nix cache cachix)

  assert (($result | length) == 1) $"Expected 1 result but got: ($result | length)"
  assert ($result.0.status == "success") $"Expected success but got: ($result.0.status)"
  assert ($result.0.cache == "cachix") $"Expected cachix cache but got: ($result.0.cache)"
  assert ($result.0.cached == false) $"Expected cached false but got: ($result.0.cached)"

  mimic verify
}

# Test: Push multiple paths in ONE cachix invocation (argv = full batch)
export def --env "test ci nix cache push multiple paths" [] {
  mimic reset

  mimic register cachix {
    args: ['push' 'cachix' '/nix/store/abc' '/nix/store/def']
    returns: ""
    exit_code: 0
  }

  let result = (['/nix/store/abc' '/nix/store/def'] | ci nix cache cachix)

  assert (($result | length) == 2) $"Expected 2 results but got: ($result | length)"
  assert ($result.0.status == "success") $"Expected success for path 0"
  assert ($result.1.status == "success") $"Expected success for path 1"

  mimic verify
}

# Test: cachix.org URL is reduced to the cache name, batch passed once
export def --env "test ci nix cache cachix url batch" [] {
  mimic reset

  mimic register cachix {
    args: ['push' 'ck3mp3r' '/nix/store/aaa' '/nix/store/bbb' '/nix/store/ccc']
    returns: ""
    exit_code: 0
  }

  let result = (['/nix/store/aaa' '/nix/store/bbb' '/nix/store/ccc'] | ci nix cache 'https://ck3mp3r.cachix.org')

  assert (($result | length) == 3) $"Expected 3 results but got: ($result | length)"
  assert (($result | where status == "success" | length) == 3) $"Expected all rows success: got ($result)"

  mimic verify
}

# Test: derivations are filtered out of the push set
export def --env "test ci nix cache filters derivations" [] {
  mimic reset

  mimic register cachix {
    args: ['push' 'cachix' '/nix/store/abc-pkg' '/nix/store/dep1']
    returns: ""
    exit_code: 0
  }

  let input = [
    "/nix/store/abc-pkg"
    "/nix/store/abc-pkg.drv"
    "/nix/store/dep1"
    "/nix/store/dep1.drv"
  ]
  let result = ($input | ci nix cache cachix)

  assert (($result | length) == 2) $"Expected 2 results after .drv filter but got: ($result | length)"
  assert (($result | where {|row| $row.path | str ends-with '.drv'} | length) == 0) $"Expected no .drv rows: got ($result)"

  mimic verify
}

# Test: non-cachix store URI uses one batched nix copy
export def --env "test ci nix cache store uri batch" [] {
  mimic reset

  mimic register nix {
    args: ['copy' '--to' 's3://bucket' '/nix/store/abc' '/nix/store/def']
    returns: ""
    exit_code: 0
  }

  let result = (['/nix/store/abc' '/nix/store/def'] | ci nix cache 's3://bucket')

  assert (($result | length) == 2) $"Expected 2 results but got: ($result | length)"
  assert (($result | where status == "success" | length) == 2) $"Expected all rows success: got ($result)"

  mimic verify
}

# Test: --upstream is accepted and ignored; one batch push happens
export def --env "test ci nix cache ignores upstream flag" [] {
  mimic reset

  mimic register cachix {
    args: ['push' 'cachix' '/nix/store/abc-pkg']
    returns: ""
    exit_code: 0
  }

  let result = (['/nix/store/abc-pkg'] | ci nix cache cachix --upstream 'https://cache.nixos.org')

  assert (($result | length) == 1) $"Expected 1 result but got: ($result | length)"
  assert ($result.0.status == "success") $"Expected success but got: ($result.0.status)"
  assert ($result.0.cached == false) $"Expected cached false but got: ($result.0.cached)"
  assert ($result.0.upstream == "https://cache.nixos.org") $"Expected upstream retained but got: ($result.0.upstream)"

  mimic verify
}

# Test: dry-run spawns no cachix process and returns dry-run rows
export def --env "test ci nix cache dry-run status" [] {
  mimic reset

  # No mocks registered: any cachix/nix spawn fails the mimic lookup and
  # would surface as an error row instead of dry-run rows
  let result = (['/nix/store/abc-pkg' '/nix/store/abc-pkg.drv'] | ci nix cache cachix --dry-run)

  assert (($result | length) == 1) $"Expected 1 result after .drv filter but got: ($result | length)"
  assert ($result.0.status == "dry-run") $"Expected dry-run status but got: ($result.0.status)"
  assert ($result.0.cached == null) $"Expected cached null but got: ($result.0.cached)"
  assert ($result.0.path == "/nix/store/abc-pkg") $"Expected the non-drv path but got: ($result.0.path)"

  mimic verify
}

# Test: batched push failure returns exactly one error row
export def --env "test ci nix cache batch failure returns error row" [] {
  mimic reset

  mimic register cachix {
    args: ['push' 'cachix' '/nix/store/bad1' '/nix/store/bad2']
    returns: "upload failed"
    exit_code: 1
  }

  let result = (['/nix/store/bad1' '/nix/store/bad2'] | ci nix cache cachix)

  assert (($result | length) == 1) $"Expected exactly 1 row but got: ($result | length)"
  assert ($result.0.path == "batch") $"Expected batch path but got: ($result.0.path)"
  assert ($result.0.status == "error") $"Expected error status but got: ($result.0.status)"
  assert ($result.0.error =~ "upload failed") $"Expected the failure message but got: ($result.0.error)"

  mimic verify
}

# Test: Pipeline - build and push to cache
export def --env "test ci nix build and push pipeline" [] {
  mimic reset

  mimic register nix {
    args: ['eval' '--impure' '--expr' 'builtins.currentSystem']
    returns: "\"x86_64-linux\""
  }

  mimic register nix {
    args: ['build' '.#pkg1' '--print-out-paths' '--no-update-lock-file']
    returns: "/nix/store/abc-pkg1"
  }

  mimic register cachix {
    args: ['push' 'cachix' '/nix/store/abc-pkg1']
    returns: ""
  }

  let result = (ci nix build pkg1 | where status == 'success' | get path | ci nix cache cachix)

  assert (($result | length) == 1) $"Expected 1 push result"
  assert ($result.0.path == "/nix/store/abc-pkg1") $"Expected correct path"
  assert ($result.0.status == "success") $"Expected success but got: ($result.0.status)"

  mimic verify
}

# ============================================================================
# IMPURE AND ARGS FLAGS TESTS
# ============================================================================

# Test 21: Check with --impure flag
export def --env "test ci nix check with impure" [] {
  mimic reset

  mimic register nix {
    args: ['flake' 'check' '--impure' '--no-update-lock-file']
    returns: ''
  }

  let result = (ci nix check --impure)

  assert ($result.0.status == "success") $"Expected success with --impure"

  mimic verify
}

# Test 22: Check with --args
export def --env "test ci nix check with args" [] {
  mimic reset

  mimic register nix {
    args: ['flake' 'check' '--verbose' '--option' 'cores' '4' '--no-update-lock-file']
    returns: ''
  }

  let result = (ci nix check --args '--verbose --option cores 4')

  assert ($result.0.status == "success") $"Expected success with --args"

  mimic verify
}

# Test 23: Build with --impure flag
export def --env "test ci nix build with impure" [] {
  mimic reset

  mimic register nix {
    args: ['eval' '--impure' '--expr' 'builtins.currentSystem']
    returns: "\"x86_64-linux\""
  }

  mimic register nix {
    args: ['build' '.#mypackage' '--print-out-paths' '--no-update-lock-file' '--impure']
    returns: "/nix/store/xyz-mypackage"
  }

  let result = (ci nix build mypackage --impure)

  assert ($result.0.status == "success") $"Expected success with --impure"
  assert ($result.0.path == "/nix/store/xyz-mypackage") $"Expected store path"

  mimic verify
}

# Test 24: Build with --args
export def --env "test ci nix build with args" [] {
  mimic reset

  mimic register nix {
    args: ['eval' '--impure' '--expr' 'builtins.currentSystem']
    returns: "\"x86_64-linux\""
  }

  mimic register nix {
    args: ['build' '.#mypackage' '--print-out-paths' '--no-update-lock-file' '--option' 'cores' '8']
    returns: "/nix/store/xyz-mypackage"
  }

  let result = (ci nix build mypackage --args '--option cores 8')

  assert ($result.0.status == "success") $"Expected success with --args"

  mimic verify
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

# ============================================================================
# PUBLISH TESTS
# ============================================================================

# Test: publish consumes build rows and returns one honest row per closure path
export def --env "test ci nix publish honest rows" [] {
  mimic reset

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/app']
    returns: "/nix/store/app\n/nix/store/dep1\n/nix/store/app.drv"
  }

  mimic register nix-store {
    args: ['--query' '--deriver' '/nix/store/app']
    returns: "unknown-deriver"
  }

  # Exact argv proves the .drv is dropped before the push
  mimic register cachix {
    args: ['push' 'mycache' '/nix/store/app' '/nix/store/dep1']
    returns: "Pushing /nix/store/app (1 KiB)\nAll done."
    exit_code: 0
  }

  let result = (
    [{flake: "." package: "app" system: "x86_64-linux" path: "/nix/store/app" status: "success" error: null}]
    | ci nix publish mycache
  )

  assert (($result | length) == 2) $"Expected 2 rows but got: ($result)"
  assert (($result | first | columns | sort) == ["error" "path" "status"]) $"Expected only path/status/error fields: got ($result)"
  assert (($result | where path == "/nix/store/app" | first | get status) == "uploaded") $"Expected app uploaded: got ($result)"
  assert (($result | where path == "/nix/store/dep1" | first | get status) == "skipped") $"Expected dep1 skipped: got ($result)"
  assert (($result | where error != null | length) == 0) $"Expected null errors: got ($result)"

  mimic verify
}

# Test: duplicates, derivations and unsorted closure order are normalised
export def --env "test ci nix publish dedups sorts drops derivations" [] {
  mimic reset

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/z-app']
    returns: "/nix/store/z-app\n/nix/store/a-dep\n/nix/store/z-app\n/nix/store/a-dep.drv\n/nix/store/m-dep"
  }

  mimic register nix-store {
    args: ['--query' '--deriver' '/nix/store/z-app']
    returns: "unknown-deriver"
  }

  # The exact sorted argv proves dedupe + derivation drop + deterministic sort
  mimic register cachix {
    args: ['push' 'mycache' '/nix/store/a-dep' '/nix/store/m-dep' '/nix/store/z-app']
    returns: "Nothing to push - all store paths are already on Cachix."
    exit_code: 0
  }

  let result = ([{path: "/nix/store/z-app" status: "success"}] | ci nix publish mycache)

  assert (($result | length) == 3) $"Expected 3 rows but got: ($result)"
  assert (($result | where {|row| $row.path | str ends-with '.drv'} | length) == 0) $"Expected no derivation rows: got ($result)"
  assert (($result | get path) == ["/nix/store/a-dep" "/nix/store/m-dep" "/nix/store/z-app"]) $"Expected sorted paths: got ($result)"

  mimic verify
}

# Fake cachix for the engine tests: logs every call and speaks the real grammar
def fake-cachix-fixture [] {
  let dir = (mktemp -d)
  let bin = ($dir | path join "bin")
  let fake = ($bin | path join "cachix")

  mkdir $bin

  [
    '#!/usr/bin/env nu'
    'def main [...args] {'
    '  let log = $env.FAKE_CACHIX_LOG'
    '  (($args | str join " ") + (char nl)) | save --append $log'
    '  let attempts = (open $log | lines | where {|line| $line | str starts-with "push " } | length)'
    '  let mode = ($env.FAKE_CACHIX_MODE? | default "ok")'
    '  if ($mode == "always-fail") or (($mode == "fail-first") and ($attempts <= 1)) {'
    '    print -e "error: HTTP 413 payload too large"'
    '    exit 1'
    '  }'
    '  $args | skip 2 | each {|path| print -e ("Pushing " + $path + " (1 KiB)") }'
    '}'
  ] | str join (char nl) | save --force $fake

  ^chmod +x $fake

  {dir: $dir bin: $bin log: ($dir | path join "calls.log")}
}

# Run a publish script in a child nu with the fake cachix first on PATH
def run-publish-script [fixture: record, mode: string, script: string] {
  with-env {
    PATH: (($env.PATH | prepend $fixture.bin) | str join (char esep))
    FAKE_CACHIX_LOG: $fixture.log
    FAKE_CACHIX_MODE: $mode
  } {
    ^nu --no-config-file -c $script | complete
  }
}

# Test: a failed batch is retried once with the identical argv
export def "test ci nix publish retries failed batch" [] {
  let fixture = (fake-cachix-fixture)
  let script = '
def --wrapped nix [...args] { "/nix/store/bad" }
def --wrapped nix-store [...args] { "unknown-deriver" }
use modules/ci/nix.nu *
[{path: "/nix/store/bad" status: "success"}] | ci nix publish mycache | get status | to json -r
'

  try {
    let result = (run-publish-script $fixture "fail-first" $script)

    assert ($result.exit_code == 0) $"Expected exit 0 after the retry, got ($result.exit_code): ($result.stderr | str trim)"
    assert (($result.stdout | str trim) == '["uploaded"]') $"Expected the retried path uploaded, got: ($result.stdout | str trim)"
    assert ((open $fixture.log | lines | length) == 2) $"Expected two push attempts, got: (open $fixture.log | lines)"
  } finally {
    rm -rf $fixture.dir
  }
}

# Test: publish exits 1 once the retry also fails and logs every failed path
export def "test ci nix publish fails after retry" [] {
  let fixture = (fake-cachix-fixture)
  let script = '
def --wrapped nix [...args] { "/nix/store/bad" }
def --wrapped nix-store [...args] { "unknown-deriver" }
use modules/ci/nix.nu *
[{path: "/nix/store/bad" status: "success"}] | ci nix publish mycache | length
'

  try {
    let result = (run-publish-script $fixture "always-fail" $script)

    assert ($result.exit_code == 1) $"Expected exit 1, got ($result.exit_code): ($result.stderr | str trim)"
    assert ((open $fixture.log | lines | length) == 2) $"Expected exactly one retry, got: (open $fixture.log | lines)"
    assert (($result.stderr | str contains "/nix/store/bad")) $"Expected the failed path in the log: ($result.stderr)"
    assert (($result.stderr | str contains "payload too large")) $"Expected the push error in the log: ($result.stderr)"
  } finally {
    rm -rf $fixture.dir
  }
}

# Test: the push set is split into argv-budget batches
export def "test ci nix publish chunks by argv budget" [] {
  let fixture = (fake-cachix-fixture)
  let script = [
    'def --wrapped nix [...args] {'
    '  1..2400 | each {|i| $"/nix/store/($i | into string | fill -a r -w 6 -c 0)-package-with-a-long-name-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } | str join (char nl)'
    '}'
    'def --wrapped nix-store [...args] { "unknown-deriver" }'
    'use modules/ci/nix.nu *'
    '[{path: "/nix/store/000001-package-with-a-long-name-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" status: "success"}] | ci nix publish mycache | length'
  ] | str join (char nl)

  try {
    let result = (run-publish-script $fixture "ok" $script)
    let calls = (open $fixture.log | lines | where {|line| $line | str starts-with "push " })
    let pushed = ($calls | each {|call| $call | split row " " | skip 2 } | flatten)

    assert ($result.exit_code == 0) $"Expected exit 0, got ($result.exit_code): ($result.stderr | str trim)"
    assert (($calls | length) > 1) $"Expected more than one batch, got: ($calls | length)"
    assert (($pushed | uniq | length) == 2400) $"Expected 2400 distinct paths across batches, got: ($pushed | uniq | length)"
    assert (($pushed | length) == 2400) $"Expected no path pushed twice, got: ($pushed | length)"
  } finally {
    rm -rf $fixture.dir
  }
}

# Test: every batch logs its outcome line, a failed batch also logs the stderr tail
export def "test ci nix publish logs batch outcome" [] {
  let script = '
def --wrapped nix [...args] { "/nix/store/aaa-pkg\n/nix/store/bbb-pkg" }
def --wrapped nix-store [...args] { "unknown-deriver" }
use modules/ci/nix.nu *
[{path: "/nix/store/aaa-pkg" status: "success"}] | ci nix publish mycache | where status == "uploaded" | length
'
  let ok_fixture = (fake-cachix-fixture)
  let fail_fixture = (fake-cachix-fixture)

  try {
    let ok_run = (run-publish-script $ok_fixture "ok" $script)
    let ok_log = ($ok_run.stderr | ansi strip)

    assert ($ok_run.exit_code == 0) $"Expected exit 0, got ($ok_run.exit_code): ($ok_log | str trim)"
    assert (($ok_run.stdout | str trim) == "2") $"Expected 2 uploaded rows, got: ($ok_run.stdout | str trim)"
    assert (($ok_log | str contains "Batch 1/1: 2 paths, ~0 KB argv, exit 0, uploaded 2, skipped 0, failed 0")) $"Expected the batch outcome line, got: ($ok_log)"

    let fail_run = (run-publish-script $fail_fixture "always-fail" $script)
    let fail_log = ($fail_run.stderr | ansi strip)

    assert ($fail_run.exit_code == 1) $"Expected exit 1, got ($fail_run.exit_code): ($fail_log | str trim)"
    assert (($fail_log | str contains "Batch 1/1: 2 paths, ~0 KB argv, exit 1, uploaded 0, skipped 0, failed 2")) $"Expected the failed batch outcome line, got: ($fail_log)"
    assert (($fail_log | str contains "error: HTTP 413 payload too large")) $"Expected the stderr tail, got: ($fail_log)"
  } finally {
    rm -rf $ok_fixture.dir
    rm -rf $fail_fixture.dir
  }
}

# Test: dry-run returns no rows and spawns no push
export def --env "test ci nix publish dry-run" [] {
  mimic reset

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/app']
    returns: "/nix/store/app\n/nix/store/dep1"
  }

  mimic register nix-store {
    args: ['--query' '--deriver' '/nix/store/app']
    returns: "unknown-deriver"
  }

  let result = ([{path: "/nix/store/app" status: "success"}] | ci nix publish mycache --dry-run)

  assert (($result | length) == 0) $"Expected no rows on dry-run but got: ($result)"
  assert ((mimic get-calls cachix | length) == 0) "Expected no cachix push on dry-run"
}

# Test: failed build rows carry no path and push nothing
export def --env "test ci nix publish ignores failed build rows" [] {
  mimic reset

  let result = (
    [{flake: "." package: "app" system: "x86_64-linux" path: null status: "failed" error: "build failed"}]
    | ci nix publish mycache
  )

  assert (($result | length) == 0) $"Expected no rows but got: ($result)"
  assert ((mimic get-calls cachix | length) == 0) "Expected no push for failed build rows"
}

# Test: the aggregate "Nothing to push" line marks the whole batch skipped
export def --env "test ci nix publish all skipped" [] {
  mimic reset

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/a']
    returns: "/nix/store/a\n/nix/store/b\n/nix/store/c"
  }

  mimic register nix-store {
    args: ['--query' '--deriver' '/nix/store/a']
    returns: "unknown-deriver"
  }

  # The cachix.org URL must reduce to the cache name
  mimic register cachix {
    args: ['push' 'ck3mp3r' '/nix/store/a' '/nix/store/b' '/nix/store/c']
    returns: "Nothing to push - all store paths are already on Cachix.\nAll done."
    exit_code: 0
  }

  let result = ([{path: "/nix/store/a" status: "success"}] | ci nix publish 'https://ck3mp3r.cachix.org')

  assert (($result | length) == 3) $"Expected 3 rows but got: ($result)"
  assert (($result | where status == "skipped" | length) == 3) $"Expected all rows skipped: got ($result)"

  mimic verify
}

# Test: a store URI pushes with nix copy and reports the complement as skipped
export def --env "test ci nix publish store uri" [] {
  mimic reset

  mimic register nix {
    args: ['path-info' '--recursive' '/nix/store/a']
    returns: "/nix/store/a\n/nix/store/b"
  }

  mimic register nix-store {
    args: ['--query' '--deriver' '/nix/store/a']
    returns: "unknown-deriver"
  }

  mimic register nix {
    args: ['copy' '--to' 's3://bucket' '/nix/store/a' '/nix/store/b']
    returns: ""
    exit_code: 0
  }

  let result = ([{path: "/nix/store/a" status: "success"}] | ci nix publish 's3://bucket')

  assert (($result | length) == 2) $"Expected 2 rows but got: ($result)"
  assert (($result | where status == "skipped" | length) == 2) $"Expected all rows skipped: got ($result)"

  mimic verify
}

# ============================================================================
# MISSING-PATHS TESTS
# ============================================================================

# Test: missing-paths filters to not cached
export def "test ci nix missing-paths filter" [] {
  let records = [
    {path: "/nix/store/abc" in_upstream: true in_cachix: false}
    {path: "/nix/store/def" in_upstream: false in_cachix: false}
  ]

  let result = ($records | ci nix missing-paths mycache)

  assert (($result | length) == 1) $"Expected 1 missing"
  assert ($result.0 == "/nix/store/def") $"Expected /nix/store/def"
}

# Test: missing-paths all cached returns empty
export def "test ci nix missing-paths all cached" [] {
  let records = [
    {path: "/nix/store/abc" in_upstream: true in_cachix: false}
  ]

  let result = ($records | ci nix missing-paths mycache)

  assert (($result | length) == 0) $"Expected empty result"
}

# Test: missing-paths writes summary to GITHUB_STEP_SUMMARY
export def "test ci nix missing-paths summary" [] {
  let test_file = $"/tmp/nu_nix_summary_(random chars).md"

  with-env {
    GITHUB_STEP_SUMMARY: $test_file
  } {
    try {
      let records = [
        {path: "/nix/store/abc" in_upstream: true in_cachix: false}
        {path: "/nix/store/def" in_upstream: false in_cachix: false}
      ]

      let result = ($records | ci nix missing-paths mycache)

      let summary = (open --raw $test_file)

      assert ($summary =~ "Cache|Count") $"Expected markdown table with cache header"
      assert (($result | length) == 1) $"Expected 1 missing"
    } finally {
      rm -f $test_file
    }
  }
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
