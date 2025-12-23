# nu-mock: Mocking framework for Nushell tests
# Main module exports

# Initialize the registry in the environment
export-env {
  $env.__NU_MOCK_REGISTRY__ = {
    expectations: {}
    calls: {}
  }
}

# Register a mock expectation (--env to preserve state)
export def --env "mock register" [
  fn_name: string
  spec: record
] {
  let existing = ($env.__NU_MOCK_REGISTRY__.expectations | get -o $fn_name | default [])
  $env.__NU_MOCK_REGISTRY__.expectations = (
    $env.__NU_MOCK_REGISTRY__.expectations
    | upsert $fn_name ($existing | append $spec)
  )
}

# Get expectation for a function call
export def "mock get-expectation" [
  fn_name: string
  args: list
] {
  use matchers.nu

  let expectations = (
    $env.__NU_MOCK_REGISTRY__.expectations
    | get -o $fn_name
    | default []
  )

  if ($expectations | is-empty) {
    error make {msg: $"No mock registered for '($fn_name)'"}
  }

  # Find first matching expectation
  for exp in $expectations {
    if (matchers matcher apply $exp.args $args) {
      return $exp
    }
  }

  # No match found
  error make {
    msg: $"No matching expectation for '($fn_name)' with args ($args)"
  }
}

# Reset all mocks (--env to preserve state)
export def --env "mock reset" [] {
  $env.__NU_MOCK_REGISTRY__ = {
    expectations: {}
    calls: {}
  }
}
