# Matcher system for nu-mimic
# Provides tiered matching: exact, regex, type-check, custom, any

# Exact matcher - args must match exactly
export def "matcher exact" [
  expected: list
  actual: list
]: nothing -> bool {
  $expected == $actual
}

# Any matcher - matches any arguments
export def "matcher any" []: nothing -> bool {
  true
}

# Wildcard matcher - matches with _ wildcards in list
# Example: ["git" "status" _] matches ["git" "status" "--porcelain"]
export def "matcher wildcard" [
  pattern: list
  actual: list
]: nothing -> bool {
  # Must have same length
  if ($pattern | length) != ($actual | length) {
    return false
  }

  # Check each position
  for i in 0..<($pattern | length) {
    let p = ($pattern | get $i)
    let a = ($actual | get $i)

    # _ matches anything, otherwise must be exact
    if $p != "_" and $p != $a {
      return false
    }
  }

  true
}

# Regex matcher - match arguments with regex patterns
export def "matcher regex" [
  pattern_spec: record # {type: "regex", pattern: "..."}
  actual_value: string
]: nothing -> bool {
  $actual_value =~ $pattern_spec.pattern
}

# Contains matcher - check if list contains a value
export def "matcher contains" [
  spec: record # {type: "contains", value: "..."}
  actual: list
]: nothing -> bool {
  $spec.value in $actual
}

# Check if matcher spec matches actual args
export def "matcher apply" [
  matcher_spec: any # The args specification from expectation
  actual_args: list # Actual arguments passed
]: nothing -> bool {
  let spec_type = ($matcher_spec | describe)

  # Special value: "any" matches everything
  if $matcher_spec == "any" {
    return true
  }

  # If spec is a list, check for wildcards or exact match
  if ($spec_type | str starts-with "list<") {
    # Check if list contains wildcards (_)
    if "_" in $matcher_spec {
      return (matcher wildcard $matcher_spec $actual_args)
    } else {
      return (matcher exact $matcher_spec $actual_args)
    }
  }

  # If spec is a record, it's an advanced matcher
  if ($spec_type | str starts-with "record") {
    let matcher_type = ($matcher_spec | get -o type)
    if $matcher_type == "regex" {
      # For regex, we need to match against all args joined
      let args_str = ($actual_args | str join " ")
      return (matcher regex $matcher_spec $args_str)
    } else if $matcher_type == "contains" {
      return (matcher contains $matcher_spec $actual_args)
    }
  }

  # Unknown matcher spec
  false
}
