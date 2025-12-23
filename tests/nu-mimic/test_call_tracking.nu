# Tests for call tracking and verification

use std assert
use ../../modules/nu-mimic *

# Test: Record calls and retrieve them
export def --env "test record and get calls" [] {
  with-mimic {
    # Register expectation
    mimic register git {
      args: ['status']
      returns: 'output'
    }

    # Record multiple calls
    mimic record-call 'git' ['status']
    mimic record-call 'git' ['status']

    # Get recorded calls
    let calls = (mimic get-calls 'git')
    assert equal 2 ($calls | length)
    assert equal ['status'] ($calls | get 0 | get args)
    assert equal ['status'] ($calls | get 1 | get args)
  }
}

# Test: Sequential expectations - times: 1 means use once then move to next
export def --env "test sequential expectations with times" [] {
  with-mimic {
    # First call returns 'first'
    mimic register git {
      args: ['status']
      returns: 'first'
      times: 1
    }

    # Second call returns 'second'
    mimic register git {
      args: ['status']
      returns: 'second'
      times: 1
    }

    # Third call returns 'third'
    mimic register git {
      args: ['status']
      returns: 'third'
    }

    # Get expectations in sequence
    let exp1 = (mimic get-expectation 'git' ['status'])
    mimic record-call 'git' ['status']

    let exp2 = (mimic get-expectation 'git' ['status'])
    mimic record-call 'git' ['status']

    let exp3 = (mimic get-expectation 'git' ['status'])
    mimic record-call 'git' ['status']

    assert equal "first" $exp1.returns
    assert equal "second" $exp2.returns
    assert equal "third" $exp3.returns
  }
}

# Test: Verify fails when expected calls not made
# This test MUST run in isolation because it expects verify to fail
export def "test verify fails on unmet expectations" [] {
  # Run in subprocess to avoid state pollution
  let test_script = "
use modules/nu-mimic *

mimic reset

# Expect 2 calls
mimic register git {
  args: ['status']
  returns: 'output'
  times: 2
}

# Only make 1 call
let exp = (mimic get-expectation 'git' ['status'])
mimic record-call 'git' ['status']

# Verify should fail
mimic verify
"

  let result = (do { nu --no-config-file -c $test_script } | complete)

  assert ($result.exit_code != 0)
  assert ($result.stderr | str contains "verification failed")
}

# Test: Verify passes when expectations met
export def --env "test verify passes when expectations met" [] {
  with-mimic {
    # Expect 2 calls
    mimic register git {
      args: ['status']
      returns: 'output'
      times: 2
    }

    # Make 2 calls (need to get expectation AND record for each)
    let exp1 = (mimic get-expectation 'git' ['status'])
    mimic record-call 'git' ['status']

    let exp2 = (mimic get-expectation 'git' ['status'])
    mimic record-call 'git' ['status']
  }
}
