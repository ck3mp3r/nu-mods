# nu-mock: Mocking framework for Nushell tests
# Main module exports

# Initialize the registry (lazy initialization)
def --env ensure-registry [] {
  if '__NU_MOCK_REGISTRY__' not-in ($env | columns) {
    $env.__NU_MOCK_REGISTRY__ = {
      expectations: {}
      calls: {}
    }
  }
}

# Register a mock expectation (--env to preserve state)
export def --env "mock register" [
  fn_name: string
  spec: record
] {
  ensure-registry

  let existing = ($env.__NU_MOCK_REGISTRY__.expectations | get -o $fn_name | default [])
  $env.__NU_MOCK_REGISTRY__.expectations = (
    $env.__NU_MOCK_REGISTRY__.expectations
    | upsert $fn_name ($existing | append $spec)
  )
}

# Record a function call (--env to preserve state)
export def --env "mock record-call" [
  fn_name: string
  args: list
] {
  ensure-registry

  let existing_calls = ($env.__NU_MOCK_REGISTRY__.calls | get -o $fn_name | default [])
  $env.__NU_MOCK_REGISTRY__.calls = (
    $env.__NU_MOCK_REGISTRY__.calls
    | upsert $fn_name ($existing_calls | append {args: $args})
  )
}

# Get expectation for a function call and mark it consumed if times: 1 (--env to preserve state)
export def --env "mock get-expectation" [
  fn_name: string
  args: list
] {
  ensure-registry

  use matchers.nu

  let expectations = (
    $env.__NU_MOCK_REGISTRY__.expectations
    | get -o $fn_name
    | default []
  )

  if ($expectations | is-empty) {
    error make {msg: $"No mock registered for '($fn_name)'"}
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
      msg: $"No matching expectation for '($fn_name)' with args ($args)"
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

    $env.__NU_MOCK_REGISTRY__.expectations = (
      $env.__NU_MOCK_REGISTRY__.expectations
      | upsert $fn_name $updated_expectations
    )
  }

  $found_exp
}

# Verify all expectations were met
export def "mock verify" [] {
  ensure-registry

  let expectations = $env.__NU_MOCK_REGISTRY__.expectations
  let calls = $env.__NU_MOCK_REGISTRY__.calls

  for fn_name in ($expectations | columns) {
    let fn_expectations = ($expectations | get $fn_name)
    let fn_calls = ($calls | get -o $fn_name | default [])

    for exp in $fn_expectations {
      let times = ($exp | get -o times | default null)

      if $times != null {
        # Count matching calls
        let matching_calls = (
          $fn_calls
          | where {|call|
            use matchers.nu
            matchers matcher apply $exp.args $call.args
          }
          | length
        )

        if $matching_calls != $times {
          error make {
            msg: $"Mock verification failed: '($fn_name)' with args ($exp.args) expected ($times) calls, got ($matching_calls)"
          }
        }
      }
    }
  }
}

# Get all recorded calls for a function
export def "mock get-calls" [fn_name: string] {
  ensure-registry

  $env.__NU_MOCK_REGISTRY__.calls | get -o $fn_name | default []
}

# Reset all mocks (--env to preserve state)
export def --env "mock reset" [] {
  ensure-registry

  $env.__NU_MOCK_REGISTRY__ = {
    expectations: {}
    calls: {}
  }
}
