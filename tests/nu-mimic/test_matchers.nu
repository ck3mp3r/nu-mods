# Tests for matcher system

use std assert
use ../../modules/nu-mimic/matchers.nu *

# Test: Wildcard matcher with _
export def "test wildcard matcher" [] {
  # Pattern with wildcard should match different values in wildcard position
  assert (matcher wildcard ['status' '_'] ['status' '--porcelain'])
  assert (matcher wildcard ['status' '_'] ['status' '--short'])

  # Pattern without wildcard at same position should not match
  assert not (matcher wildcard ['status' '--porcelain'] ['status' '--short'])

  # Different lengths should not match
  assert not (matcher wildcard ['status' '_'] ['status'])
  assert not (matcher wildcard ['status'] ['status' '--porcelain'])
}

# Test: Any matcher
export def "test any matcher" [] {
  # Any matcher should always return true
  assert (matcher any)
}

# Test: Regex matcher
export def "test regex matcher" [] {
  # Regex matcher should match pattern
  assert (matcher regex {type: "regex" pattern: 'status.*porcelain'} 'status --porcelain')
  assert (matcher regex {type: "regex" pattern: '^status'} 'status --short')

  # Should not match when pattern doesn't match
  assert not (matcher regex {type: "regex" pattern: '^push'} 'status --porcelain')
}

# Test: Exact matcher
export def "test exact matcher" [] {
  # Exact matcher should match when lists are identical
  assert (matcher exact ['status' '--porcelain'] ['status' '--porcelain'])
  assert (matcher exact ['push'] ['push'])

  # Should not match when different
  assert not (matcher exact ['status' '--porcelain'] ['status' '--short'])
  assert not (matcher exact ['status'] ['status' '--porcelain'])
}

# Test: Matcher apply - delegates to correct matcher
export def "test matcher apply" [] {
  # Test with exact match (list)
  assert (matcher apply ['status' '--porcelain'] ['status' '--porcelain'])

  # Test with wildcard (list with _)
  assert (matcher apply ['status' '_'] ['status' '--porcelain'])

  # Test with any
  assert (matcher apply 'any' ['anything' 'goes' 'here'])

  # Test with regex (record)
  assert (matcher apply {type: 'regex' pattern: 'status.*'} ['status' '--porcelain'])

  # Test with contains (record)
  assert (matcher apply {type: 'contains' value: 'status'} ['git' 'status' '--porcelain'])
}

# Test: Contains matcher
export def "test contains matcher" [] {
  # Should match when value is in list
  assert (matcher contains {type: 'contains' value: 'status'} ['git' 'status' '--porcelain'])
  assert (matcher contains {type: 'contains' value: '--porcelain'} ['status' '--porcelain'])

  # Should not match when value not in list
  assert not (matcher contains {type: 'contains' value: 'push'} ['git' 'status' '--porcelain'])
}
