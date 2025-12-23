# Test: Proper mock usage pattern
# 1. Setup expectations upfront
# 2. Run code under test (using wrapped functions)
# 3. Verify expectations met

use std assert
use ../../modules/nu-mimic *

# Test: Complete workflow - setup, run, verify
export def --env "test complete mock workflow" [] {
  mimic reset

  # 1. Setup all expectations upfront
  mimic register git {
    args: ['status']
    returns: 'clean'
    times: 2
  }

  mimic register git {
    args: ['push']
    returns: 'success'
    times: 1
  }

  # 2. Create wrapper for git using --wrapped
  def --env --wrapped git [...args] { mimic call 'git' $args }

  # 3. Run code under test
  def --env my-git-workflow [] {
    # Just call git naturally!
    let status1 = (git status)
    let status2 = (git status)
    let push_result = (git push)

    {status1: $status1 status2: $status2 push: $push_result}
  }

  let results = (my-git-workflow)

  # Verify the mocked values were returned
  assert equal 'clean' $results.status1
  assert equal 'clean' $results.status2
  assert equal 'success' $results.push

  # 4. Verify all expectations were met
  mimic verify
}

# Test: Verify catches missing calls
# This test MUST use subprocess isolation because it expects verify to fail
export def "test verify detects unmet expectations" [] {
  let test_script = "
use modules/nu-mimic *

mimic reset

# Setup expectation for 2 calls
mimic register git {
  args: ['status']
  returns: 'output'
  times: 2
}

# Only make 1 call
mimic call 'git' ['status']

# This should fail
mimic verify
"

  let result = (do { nu --no-config-file -c $test_script } | complete)

  assert ($result.exit_code != 0)
  assert ($result.stderr | str contains "expected 2 calls")
}

# Test: Wrapped function pattern with exit codes
# This test MUST use subprocess isolation because it expects mimic call to error
export def "test wrapped function with error" [] {
  let test_script = "
use modules/nu-mimic *

mimic reset

mimic register git {
  args: ['push']
  returns: 'fatal: remote error'
  exit_code: 1
}

# This should error
mimic call 'git' ['push']
"

  let result = (do { nu --no-config-file -c $test_script } | complete)

  assert ($result.exit_code != 0)
  assert ($result.stderr | str contains "fatal: remote error")
}
