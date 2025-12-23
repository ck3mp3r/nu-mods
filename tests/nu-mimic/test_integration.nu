# Integration tests: nu-mimic registry and matcher integration
# Tests that the full system works together

use std assert
use ../../modules/nu-mimic *

# Test: Mock git command with exact match
export def "test mimic git with exact args" [] {
  with-mimic {
    # Register expectation
    mimic register git {
      args: ['status' '--porcelain']
      returns: '?? file.txt'
    }

    # Get expectation
    let expectation = (mimic get-expectation 'git' ['status' '--porcelain'])
    assert equal "?? file.txt" $expectation.returns
  }
}

# Test: Mock with multiple expectations (different args)
export def "test mimic multiple expectations" [] {
  with-mimic {
    mimic register git {
      args: ['status']
      returns: 'clean'
    }

    mimic register git {
      args: ['diff']
      returns: 'changes'
    }

    # Get different expectations
    let exp1 = (mimic get-expectation 'git' ['status'])
    let exp2 = (mimic get-expectation 'git' ['diff'])

    assert equal "clean" $exp1.returns
    assert equal "changes" $exp2.returns
  }
}

# Test: Wildcard matching integration
export def "test wildcard integration" [] {
  with-mimic {
    mimic register git {
      args: ['status' '_']
      returns: 'matched with wildcard'
    }

    # Should match with any second argument
    let exp1 = (mimic get-expectation 'git' ['status' '--porcelain'])
    let exp2 = (mimic get-expectation 'git' ['status' '--short'])

    assert equal "matched with wildcard" $exp1.returns
    assert equal "matched with wildcard" $exp2.returns
  }
}

# Test: Any matcher integration
export def "test any matcher integration" [] {
  with-mimic {
    mimic register input {
      args: any
      returns: 'y'
    }

    # Should match any arguments
    let exp1 = (mimic get-expectation 'input' ['Do you want to continue?'])
    let exp2 = (mimic get-expectation 'input' [])
    let exp3 = (mimic get-expectation 'input' ['foo' 'bar' 'baz'])

    assert equal 'y' $exp1.returns
    assert equal 'y' $exp2.returns
    assert equal 'y' $exp3.returns
  }
}
