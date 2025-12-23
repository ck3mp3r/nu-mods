# Integration tests: nu-mock registry and matcher integration
# Tests that the full system works together

use std assert
use ../../modules/nu-mock *

# Test: Mock git command with exact match
export def "test mock git with exact args" [] {
  mock reset

  # Register expectation
  mock register git {
    args: ['status' '--porcelain']
    returns: '?? file.txt'
  }

  # Get expectation
  let expectation = (mock get-expectation 'git' ['status' '--porcelain'])
  assert equal "?? file.txt" $expectation.returns
}

# Test: Mock with multiple expectations (different args)
export def "test mock multiple expectations" [] {
  mock reset

  mock register git {
    args: ['status']
    returns: 'clean'
  }

  mock register git {
    args: ['diff']
    returns: 'changes'
  }

  # Get different expectations
  let exp1 = (mock get-expectation 'git' ['status'])
  let exp2 = (mock get-expectation 'git' ['diff'])

  assert equal "clean" $exp1.returns
  assert equal "changes" $exp2.returns
}

# Test: Wildcard matching integration
export def "test wildcard integration" [] {
  mock reset

  mock register git {
    args: ['status' '_']
    returns: 'matched with wildcard'
  }

  # Should match with any second argument
  let exp1 = (mock get-expectation 'git' ['status' '--porcelain'])
  let exp2 = (mock get-expectation 'git' ['status' '--short'])

  assert equal "matched with wildcard" $exp1.returns
  assert equal "matched with wildcard" $exp2.returns
}

# Test: Any matcher integration
export def "test any matcher integration" [] {
  mock reset

  mock register input {
    args: any
    returns: 'y'
  }

  # Should match any arguments
  let exp1 = (mock get-expectation 'input' ['Do you want to continue?'])
  let exp2 = (mock get-expectation 'input' [])
  let exp3 = (mock get-expectation 'input' ['foo' 'bar' 'baz'])

  assert equal 'y' $exp1.returns
  assert equal 'y' $exp2.returns
  assert equal 'y' $exp3.returns
}
