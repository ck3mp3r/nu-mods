# Tests for matcher system

use std assert

# Test: Wildcard matcher with _
export def "test wildcard matcher" [] {
  let test_script = "
use modules/nu-mock *

mock register git {
  args: ['status' _]
  returns: 'wildcard matched'
}

def --wrapped git [...args] {
  let expectation = (mock get-expectation 'git' $args)
  $expectation.returns
}

git status --porcelain
"

  let output = (nu --no-config-file -c $test_script)
  assert equal "wildcard matched" $output
}

# Test: Any matcher
export def "test any matcher" [] {
  let test_script = "
use modules/nu-mock *

mock register input {
  args: any
  returns: 'y'
}

def --wrapped input [...args] {
  let expectation = (mock get-expectation 'input' $args)
  $expectation.returns
}

print (input 'Do you want to continue?')
print (input)
"

  let output = (nu --no-config-file -c $test_script | lines)
  assert equal "y" ($output | get 0)
  assert equal "y" ($output | get 1)
}

# Test: Regex matcher
export def "test regex matcher" [] {
  let test_script = "
use modules/nu-mock *

mock register git {
  args: {type: regex, pattern: 'status --porcelain'}
  returns: 'regex matched'
}

def --wrapped git [...args] {
  let expectation = (mock get-expectation 'git' $args)
  $expectation.returns
}

git status --porcelain
"

  let output = (nu --no-config-file -c $test_script)
  assert equal "regex matched" $output
}

# Test: Exit code handling
export def "test exit code error" [] {
  let test_script = "
use modules/nu-mock *

mock register git {
  args: ['push']
  returns: 'fatal: remote error'
  exit_code: 1
}

def --wrapped git [...args] {
  let expectation = (mock get-expectation 'git' $args)
  
  let exit_code = ($expectation | get -o exit_code | default 0)
  if $exit_code != 0 {
    error make {msg: $\"Git error: ($expectation.returns)\"}
  }
  
  $expectation.returns
}

git push
"

  # This should error - check via exit code
  let result = (do { nu --no-config-file -c $test_script } | complete)

  assert ($result.exit_code != 0)
  assert ($result.stderr | str contains "Git error")
}
