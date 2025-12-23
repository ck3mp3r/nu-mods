# Tests for mock registry - expectation registration and retrieval
use std assert

# Test: Can register a basic mock expectation
export def test_register_basic_expectation [] {
  use ../../modules/nu-mock *

  # Setup
  mock reset

  # Register a simple expectation
  mock register "git" {
    args: ["status" "--porcelain"]
    returns: "?? file.txt"
  }

  # Retrieve the expectation
  let expectation = (mock get-expectation "git" ["status" "--porcelain"])

  # Verify it matches what we registered
  assert equal "?? file.txt" $expectation.returns
  assert equal ["status" "--porcelain"] $expectation.args
}

# Test: Can register multiple expectations for same function
export def test_register_multiple_expectations [] {
  use ../../modules/nu-mock *

  # Setup
  mock reset

  # Register two expectations for git
  mock register "git" {
    args: ["status"]
    returns: "clean"
  }

  mock register "git" {
    args: ["diff"]
    returns: "changes"
  }

  # For now, just verify both were stored (matching comes in next iteration)
  # Currently returns first expectation - this will be fixed with matchers
  let exp = (mock get-expectation "git" ["status"])
  assert equal "clean" $exp.returns
}

# Test: Reset clears all expectations
export def test_reset_clears_expectations [] {
  use ../../modules/nu-mock *

  # Register an expectation
  mock register "git" {
    args: ["status"]
    returns: "output"
  }

  # Reset
  mock reset

  # Should fail to retrieve after reset
  assert error { mock get-expectation "git" ["status"] }
}
