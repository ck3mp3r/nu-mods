# Integration test: nu-mock with wrapped functions
# This demonstrates the real-world usage pattern

use std assert

# Test: Mock git command with exact match
export def "test mock git with exact args" [] {
  let test_script = "
use modules/nu-mock *

# Register expectation
mock register git {
  args: ['status' '--porcelain']
  returns: '?? file.txt'
}

# Define wrapped function
def --env --wrapped git [...args] {
  let expectation = (mock get-expectation 'git' $args)
  $expectation.returns
}

# Call it
git status --porcelain
"

  let output = (nu --no-config-file -c $test_script)
  assert equal "?? file.txt" $output
}

# Test: Mock with multiple expectations (different args)
export def "test mock multiple expectations" [] {
  let test_script = "
use modules/nu-mock *

mock register git {
  args: ['status']
  returns: 'clean'
}

mock register git {
  args: ['diff']  
  returns: 'changes'
}

def --env --wrapped git [...args] {
  let expectation = (mock get-expectation 'git' $args)
  $expectation.returns
}

print (git status)
print (git diff)
"

  let output = (nu --no-config-file -c $test_script | lines)
  assert equal "clean" ($output | get 0)
  assert equal "changes" ($output | get 1)
}
