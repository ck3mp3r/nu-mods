# Matcher system for nu-mock
# Provides tiered matching: exact, regex, type-check, custom

# Exact matcher - args must match exactly
export def "matcher exact" [
  expected: list
  actual: list
]: nothing -> bool {
  $expected == $actual
}

# Check if matcher spec matches actual args
export def "matcher apply" [
  matcher_spec: any # The args specification from expectation
  actual_args: list # Actual arguments passed
]: nothing -> bool {
  let spec_type = ($matcher_spec | describe)

  # If spec is a list (any type), use exact matching
  if ($spec_type | str starts-with "list<") {
    matcher exact $matcher_spec $actual_args
  } else {
    # TODO: Advanced matchers (regex, type, custom)
    false
  }
}
