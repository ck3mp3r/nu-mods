# Test: Proper mock usage pattern
# 1. Setup expectations upfront
# 2. Run code under test (using wrapped functions)
# 3. Verify expectations met

use std assert
use ../../modules/nu-mimic *

# Test: Complete workflow - setup, run, verify
export def --env "test complete mock workflow" [] {
  with-mimic {
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
  }
}

# Test: Verify catches missing calls
export def "test verify detects unmet expectations" [] {
  let result = (
    try {
      with-mimic {
        # Setup expectation for 2 calls
        mimic register git {
          args: ['status']
          returns: 'output'
          times: 2
        }

        # Only make 1 call
        mimic call 'git' ['status']
      }
      null
    } catch {|err|
      $err
    }
  )

  assert ($result != null)
  assert ($result.msg | str contains "verification failed")
}

# Test: Wrapped function pattern with exit codes
export def "test wrapped function with error" [] {
  let result = (
    try {
      with-mimic {
        mimic register git {
          args: ['push']
          returns: 'fatal: remote error'
          exit_code: 1
        }

        # This should error
        mimic call 'git' ['push']
      }
      null
    } catch {|err|
      $err
    }
  )

  assert ($result != null)
  assert ($result.msg | str contains "fatal: remote error")
}

# Test: with-mimic helper - successful test
export def --env "test with-mimic helper success" [] {
  with-mimic {
    mimic register git {
      args: ['status']
      returns: 'clean'
    }

    let result = (mimic call 'git' ['status'])
    assert equal 'clean' $result
  }
  # Verify should have been called automatically
}

# Test: with-mimic helper - handles test errors and still verifies
export def "test with-mimic helper verifies on error" [] {
  let result = (
    try {
      with-mimic {
        mimic register git {
          args: ['status']
          returns: 'output'
          times: 2
        }

        # Only make 1 call
        mimic call 'git' ['status']

        # Don't call verify - with-mimic should do it
      }
      null
    } catch {|err|
      $err
    }
  )

  # Should fail because verify detects unmet expectations
  assert ($result != null)
  assert ($result.msg | str contains "verification failed")
}

# Test: with-mimic helper - reset happens automatically
export def --env "test with-mimic helper auto resets" [] {
  # Set up some state
  mimic register git {
    args: ['old']
    returns: 'old data'
  }

  # with-mimic should reset this
  with-mimic {
    # This should work without errors about 'old' expectation
    mimic register git {
      args: ['status']
      returns: 'clean'
    }

    let result = (mimic call 'git' ['status'])
    assert equal 'clean' $result
  }
}
