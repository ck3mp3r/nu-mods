# nu-mimic: Mocking framework for Nushell tests
#
# Usage:
#   use modules/nu-mimic *
#
#   # Recommended: Use with-mimic helper
#   export def --env "test my feature" [] {
#     with-mimic {
#       mimic register git { args: ['status'], returns: 'clean' }
#       
#       let result = (some_function_that_calls_git)
#       assert equal 'expected' $result
#       # reset and verify happen automatically
#     }
#   }
#
#   # Or manual approach:
#   mimic reset
#   mimic register git { args: ['status'], returns: 'clean' }
#   def --env --wrapped git [...args] { mimic call 'git' $args }
#   git status  # Returns 'clean'
#   mimic verify

# Initialize the registry (lazy initialization)
def --env ensure-registry [] {
  if '__NU_MIMIC_REGISTRY__' not-in ($env | columns) {
    $env.__NU_MIMIC_REGISTRY__ = {
      expectations: {}
      calls: {}
    }
  }
}

# Register a mimic expectation (--env to preserve state)
export def --env "mimic register" [
  command: string # External command/CLI name (e.g., 'git', 'nix', 'curl')
  spec: record
] {
  ensure-registry

  let existing = ($env.__NU_MIMIC_REGISTRY__.expectations | get -o $command | default [])
  $env.__NU_MIMIC_REGISTRY__.expectations = (
    $env.__NU_MIMIC_REGISTRY__.expectations
    | upsert $command ($existing | append $spec)
  )
}

# Record a command call (--env to preserve state)
export def --env "mimic record-call" [
  command: string # External command/CLI name
  args: list
] {
  ensure-registry

  let existing_calls = ($env.__NU_MIMIC_REGISTRY__.calls | get -o $command | default [])
  $env.__NU_MIMIC_REGISTRY__.calls = (
    $env.__NU_MIMIC_REGISTRY__.calls
    | upsert $command ($existing_calls | append {args: $args})
  )
}

# Get expectation for a command call and mark it consumed if times: 1 (--env to preserve state)
export def --env "mimic get-expectation" [
  command: string # External command/CLI name
  args: list
] {
  ensure-registry

  use matchers.nu

  let expectations = (
    $env.__NU_MIMIC_REGISTRY__.expectations
    | get -o $command
    | default []
  )

  if ($expectations | is-empty) {
    error make {msg: $"No mimic registered for '($command)'"}
  }

  # Find first matching expectation and mark as consumed if needed
  mut found_idx = -1
  mut found_exp = null

  for exp in ($expectations | enumerate) {
    let idx = $exp.index
    let expectation = $exp.item

    if (matchers matcher apply $expectation.args $args) {
      # Check if this expectation was already consumed
      let consumed = ($expectation | get -o consumed | default false)
      let times = ($expectation | get -o times | default null)

      # If consumed and has times limit, skip to next expectation
      if $consumed and $times != null {
        continue
      }

      # Found a usable expectation
      $found_idx = $idx
      $found_exp = $expectation
      break
    }
  }

  if $found_idx == -1 {
    error make {
      msg: $"No matching expectation for '($command)' with args ($args)"
    }
  }

  # Mark as consumed if times: 1
  let times = ($found_exp | get -o times | default null)
  if $times == 1 {
    let idx_to_mark = $found_idx # Capture the value before closure
    let updated_expectations = (
      $expectations
      | enumerate
      | each {|item|
        if $item.index == $idx_to_mark {
          $item.item | upsert consumed true
        } else {
          $item.item
        }
      }
    )

    $env.__NU_MIMIC_REGISTRY__.expectations = (
      $env.__NU_MIMIC_REGISTRY__.expectations
      | upsert $command $updated_expectations
    )
  }

  $found_exp
}

# Verify all expectations were met
export def "mimic verify" [] {
  ensure-registry

  let expectations = $env.__NU_MIMIC_REGISTRY__.expectations
  let calls = $env.__NU_MIMIC_REGISTRY__.calls

  for command in ($expectations | columns) {
    let cmd_expectations = ($expectations | get $command)
    let cmd_calls = ($calls | get -o $command | default [])

    for exp in $cmd_expectations {
      # Skip consumed expectations (times: 1 that were already used)
      if ($exp | get -o consumed | default false) {
        continue
      }

      let times = ($exp | get -o times | default null)

      if $times != null {
        # Count matching calls
        let matching_calls = (
          $cmd_calls
          | where {|call|
            use matchers.nu
            matchers matcher apply $exp.args $call.args
          }
          | length
        )

        if $matching_calls != $times {
          error make {
            msg: $"Mimic verification failed: '($command)' with args ($exp.args) expected ($times) calls, got ($matching_calls)"
          }
        }
      }
    }
  }
}

# Execute a mimic call - gets expectation AND records call automatically
# This is what wrapped commands should use
export def --env "mimic call" [
  command: string # External command/CLI name
  args: list
] {
  ensure-registry

  # Get the expectation
  let expectation = (mimic get-expectation $command $args)

  # Record the call
  mimic record-call $command $args

  # Handle exit codes
  let exit_code = ($expectation | get -o exit_code | default 0)
  if $exit_code != 0 {
    error make {
      msg: $expectation.returns
    }
  }

  # Return the mocked value
  $expectation.returns
}

# Get all recorded calls for a command
export def "mimic get-calls" [
  command: string # External command/CLI name
] {
  ensure-registry

  $env.__NU_MIMIC_REGISTRY__.calls | get -o $command | default []
}

# Reset all mimics (--env to preserve state)
export def --env "mimic reset" [] {
  ensure-registry

  $env.__NU_MIMIC_REGISTRY__ = {
    expectations: {}
    calls: {}
  }
}

# Helper to run test with automatic reset and verify
# Wraps a test closure to handle boilerplate setup/teardown
export def "with-mimic" [
  test_fn: closure # Test code to run
] {
  mimic reset

  let test_error = (
    try {
      do --env $test_fn
      null
    } catch {|err|
      $err
    }
  )

  # Always verify, even if test errored
  mimic verify

  # Re-throw test error if there was one
  if $test_error != null {
    error make {msg: $test_error.msg}
  }
}
