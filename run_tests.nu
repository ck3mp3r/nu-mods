#!/usr/bin/env nu

# Test runner for nu-mods
# Auto-discovers test functions with "test " prefix

def main [] {
  print "Running tests...\n"

  # Test suites - files and their test functions
  let test_suites = {
    "tests/test_provider.nu": [
      "test provider run with valid response"
      "test provider run strips thinking tags"
      "test provider run handles empty response"
    ]
    "tests/test_git.nu": [
      "test ai git pr with custom model and target"
      "test ai git pr with prefix"
      "test ai git commit with custom model"
      "test ai git branch with description and prefix"
      "test ai git branch from current"
      "test ai git commit extracts branch prefix"
    ]
  }

  let results = (
    $test_suites | items {|test_file test_list|
      print $"=== Running tests from ($test_file) ==="

      # Run each test
      $test_list | each {|test_name|
        try {
          nu --no-config-file -c $"source ($test_file); ($test_name)"
          print $"✓ ($test_name)"
          {test: $test_name status: "pass"}
        } catch {|err|
          print $"✗ ($test_name): ($err.msg)"
          {test: $test_name status: "fail" error: $err.msg}
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
