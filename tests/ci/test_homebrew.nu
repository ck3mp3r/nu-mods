# Test ci/homebrew.nu - pure string transformation
# Focus: Test formula version/hash update

use std/assert
use ../../modules/ci/homebrew.nu *

# Test 1: Replace version and vX.Y.Z
export def "test ci homebrew update version and vref" [] {
  let formula = $"""
class Context < Formula
  version "0.1.0"
  url "https://example.com/context-v0.1.0.tgz"
end
"""

  let result = ($formula | ci homebrew update-formula "0.2.0" "context" [])

  assert ($result =~ "version \"0.2.0\"") $"Expected version 0.2.0"
  assert ($result =~ "v0.2.0") $"Expected v0.2.0"
  assert (not ($result =~ "0.1.0")) $"Expected no 0.1.0"
}

# Test 2: Replace per-arch filename and hash
export def "test ci homebrew update arch" [] {
  let formula = $"""
class Context < Formula
  version "0.1.0"
  url "https://example.com/context-0.1.0-aarch64-darwin.tgz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
end
"""

  let result = ($formula | ci homebrew update-formula "0.2.0" "context" [{name: "aarch64-darwin" hash: "abc123"}])

  assert ($result =~ "context-0.2.0-aarch64-darwin.tgz") $"Expected updated filename"
  assert ($result =~ "sha256 \"abc123\"") $"Expected updated hash"
}

# Test 3: Multiple architectures
export def "test ci homebrew update multiple arches" [] {
  let formula = $"""
class Context < Formula
  version "0.1.0"
  url "https://example.com/context-0.1.0-aarch64-darwin.tgz"
  sha256 "1111111111111111111111111111111111111111111111111111111111111111"
  url "https://example.com/context-0.1.0-x86_64-darwin.tgz"
  sha256 "2222222222222222222222222222222222222222222222222222222222222222"
end
"""

  let arches = [
    {name: "aarch64-darwin" hash: "new1"}
    {name: "x86_64-darwin" hash: "new2"}
  ]
  let result = ($formula | ci homebrew update-formula "0.2.0" "context" $arches)

  assert ($result =~ "context-0.2.0-aarch64-darwin.tgz") $"Expected first filename"
  assert ($result =~ "sha256 \"new1\"") $"Expected first hash"
  assert ($result =~ "context-0.2.0-x86_64-darwin.tgz") $"Expected second filename"
  assert ($result =~ "sha256 \"new2\"") $"Expected second hash"
}

# Test 4: Idempotent when already current
export def "test ci homebrew update idempotent" [] {
  let formula = $"""
class Context < Formula
  version "0.2.0"
  url "https://example.com/context-0.2.0-aarch64-darwin.tgz"
  sha256 "abc123"
end
"""

  let result = $formula | ci homebrew update-formula "0.2.0" "context" [{name: "aarch64-darwin" hash: "abc123"}]

  assert ($result == $formula) $"Expected unchanged formula"
}
