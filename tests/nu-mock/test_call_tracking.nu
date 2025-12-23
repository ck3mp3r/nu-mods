# Tests for call tracking and verification

use std assert

# Test: Record calls and retrieve them
export def "test record and get calls" [] {
  let test_script = "
use modules/nu-mock *

mock reset

# Register expectation
mock register git {
  args: ['status']
  returns: 'output'
}

def --env --wrapped git [...args] {
  mock record-call 'git' $args
  let exp = (mock get-expectation 'git' $args)
  $exp.returns
}

# Make multiple calls
git status
git status

# Get recorded calls
let calls = (mock get-calls 'git')
$calls | length
"

  let count = (nu --no-config-file -c $test_script)
  assert equal 2 ($count | into int)
}

# Test: Sequential expectations - times: 1 means use once then move to next
export def "test sequential expectations with times" [] {
  let test_script = "
use modules/nu-mock *

mock reset

# First call returns 'first'
mock register git {
  args: ['status']
  returns: 'first'
  times: 1
}

# Second call returns 'second'
mock register git {
  args: ['status']
  returns: 'second'
  times: 1
}

# Third call returns 'third'
mock register git {
  args: ['status']
  returns: 'third'
}

def --env --wrapped git [...args] {
  mock record-call 'git' $args
  let exp = (mock get-expectation 'git' $args)
  $exp.returns
}

# Make three calls
print (git status)
print (git status)
print (git status)
"

  let output = (nu --no-config-file -c $test_script | lines)
  assert equal "first" ($output | get 0)
  assert equal "second" ($output | get 1)
  assert equal "third" ($output | get 2)
}

# Test: Verify fails when expected calls not made
export def "test verify fails on unmet expectations" [] {
  let test_script = "
use modules/nu-mock *

mock reset

# Expect 2 calls
mock register git {
  args: ['status']
  returns: 'output'
  times: 2
}

def --env --wrapped git [...args] {
  mock record-call 'git' $args
  let exp = (mock get-expectation 'git' $args)
  $exp.returns
}

# Only make 1 call
git status

# Verify should fail
mock verify
"

  let result = (do { nu --no-config-file -c $test_script } | complete)

  assert ($result.exit_code != 0)
  assert ($result.stderr | str contains "expected 2 calls, got 1")
}

# Test: Verify passes when expectations met
export def "test verify passes when expectations met" [] {
  let test_script = "
use modules/nu-mock *

mock reset

# Expect 2 calls
mock register git {
  args: ['status']
  returns: 'output'
  times: 2
}

def --env --wrapped git [...args] {
  mock record-call 'git' $args
  let exp = (mock get-expectation 'git' $args)
  $exp.returns
}

# Make 2 calls
git status
git status

# Verify should pass
mock verify
print 'verified'
"

  let output = (nu --no-config-file -c $test_script)
  assert equal "verified" $output
}
