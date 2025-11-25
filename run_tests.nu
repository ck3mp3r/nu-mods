#!/usr/bin/env nu

# Test runner for nu-mods

def main [] {
  # Define test suites
  let test_suites = {
    provider: {
      file: "tests/test_provider.nu"
      tests: [
        "test provider run with valid response"
        "test provider run strips thinking tags"
        "test provider run handles empty response"
      ]
    }
    git: {
      file: "tests/test_git.nu"
      tests: [
        "test ai git pr with custom model and target"
        "test ai git pr with prefix"
        "test ai git commit with custom model"
        "test ai git branch with description and prefix"
        "test ai git branch from current"
        "test ai git commit extracts branch prefix"
      ]
    }
  }

  # Run all tests
  let results = (
    $test_suites | items {|suite_name suite|
      print $"\n=== Running ($suite_name) tests ==="

      $suite.tests | each {|test_name|
        try {
          # Run test with --no-config-file to avoid loading user config
          nu --no-config-file -c $"cd ($env.PWD); source ($suite.file); ($test_name)"
          print $"✓ ($test_name)"
          {suite: $suite_name test: $test_name status: "pass"}
        } catch {|err|
          print $"✗ ($test_name): ($err.msg)"
          {suite: $suite_name test: $test_name status: "fail" error: $err.msg}
        }
      }
    } | flatten
  )

  # Summary
  let passed = ($results | where status == "pass" | length)
  let failed = ($results | where status == "fail" | length)
  let total = ($results | length)

  print ""
  print $"Results: ($passed)/($total) passed, ($failed) failed"

  if $failed > 0 {
    exit 1
  }
}
