---
name: nushell-testing
description: Testing patterns in Nushell using the nu-mimic mocking framework. Use when writing tests, mocking external commands, or verifying Nushell code behavior.
---

# Nushell Testing Patterns

This skill covers testing patterns in Nushell, including the nu-mimic mocking framework, test organization, and verification strategies.

## Core Concepts

### Test Organization

Tests in Nushell are typically organized as exported functions with descriptive names:

```nu
# Test function naming convention
export def --env "test feature name" [] {
    # Test implementation
}

# Example
export def --env "test git status returns clean" [] {
    # Setup, execute, assert
}
```

**Key points:**
- Use `--env` flag to allow environment modifications (required for mocking)
- Descriptive test names as strings (not identifiers)
- Export tests so they can be discovered and run

## Mocking with nu-mimic

### Basic Mocking Pattern

The recommended pattern uses `with-mimic` for automatic setup/teardown:

```nu
export def --env "test my feature" [] {
    with-mimic {
        # Register mock
        mimic register git {args: ['status'], returns: 'clean'}
        
        # Execute test
        let result = (some_function_that_calls_git)
        
        # Assert
        assert equal 'expected' $result
        # reset and verify happen automatically
    }
}
```

**Why use `with-mimic`?**
- Automatically calls `mimic reset` before test
- Automatically calls `mimic verify` after test (even if test errors)
- Ensures clean state between tests
- Simplifies test code

### Manual Mocking Pattern

For more control, you can manage the lifecycle manually:

```nu
export def --env "test my feature" [] {
    mimic reset
    
    mimic register git {args: ['status'], returns: 'clean'}
    
    # Create wrapped command
    def --env --wrapped git [...args] { mimic call 'git' $args }
    
    # Execute
    let result = (git status)  # Returns 'clean'
    
    # Verify
    mimic verify
}
```

**When to use manual pattern:**
- Need to verify at multiple points in test
- Complex test scenarios with multiple phases
- Need to inspect calls mid-test

## Wrapped Commands

The `--wrapped` flag is critical for mocking external commands:

```nu
# Override external command with mock
def --env --wrapped git [...args] { 
    mimic call 'git' $args 
}
```

**Key elements:**
- `--env`: Ensures environment changes (mock registry updates) persist
- `--wrapped`: Tells Nushell this shadows an external command
- `...args`: Captures all arguments as a list (rest parameter)

**How it works:**
1. Nushell prioritizes custom commands over external binaries
2. `--wrapped` explicitly declares you're shadowing an external command
3. `mimic call` looks up expectation, records the call, returns mocked value

## Matcher Patterns

nu-mimic supports multiple matcher types for flexible expectations:

### Exact Match
```nu
mimic register git {args: ['status', '--porcelain'], returns: 'M file.txt'}
# Only matches exactly: git status --porcelain
```

### Wildcard Match
```nu
mimic register git {args: ['status', '_'], returns: 'clean'}
# Matches: git status <anything>
# Examples: git status --porcelain, git status -v, etc.
```

### Any Match
```nu
mimic register git {args: "any", returns: 'default'}
# Matches any git call with any arguments
```

### Regex Match
```nu
mimic register git {
    args: {type: "regex", pattern: "status.*porcelain"}
    returns: 'M file.txt'
}
# Matches if joined args match regex
```

### Contains Match
```nu
mimic register git {
    args: {type: "contains", value: "--verbose"}
    returns: 'verbose output'
}
# Matches if args list contains the value
```

## Call Verification

### Times Expectation

Verify a command is called exactly N times:

```nu
with-mimic {
    mimic register git {args: ['status'], times: 3, returns: 'clean'}
    
    # Call git status 3 times
    git status
    git status
    git status
    
    # Verify automatically checks it was called exactly 3 times
}
```

**How `times` works:**
- Records number of calls to matching expectation
- `mimic verify` checks actual calls == expected times
- Error if mismatch

### One-time Expectations

Special case: `times: 1` marks expectation as "consumed" after first use:

```nu
with-mimic {
    mimic register git {args: ['status'], times: 1, returns: 'first'}
    mimic register git {args: ['status'], returns: 'subsequent'}
    
    git status  # Returns 'first', marks first expectation consumed
    git status  # Returns 'subsequent', uses second expectation
}
```

**Use case:** Simulating state changes (first call returns X, subsequent return Y)

### Getting Call History

Inspect recorded calls for a command:

```nu
with-mimic {
    mimic register git {args: "any", returns: 'ok'}
    
    git status
    git log --oneline
    
    let calls = (mimic get-calls 'git')
    # Returns: [
    #   {args: ['status']}
    #   {args: ['log', '--oneline']}
    # ]
}
```

## Error Simulation

Simulate command failures with `exit_code`:

```nu
with-mimic {
    mimic register git {
        args: ['push']
        exit_code: 1
        returns: 'fatal: remote rejected'
    }
    
    # This will error
    try {
        git push
    } catch {|err|
        assert ($err.msg == 'fatal: remote rejected')
    }
}
```

**How it works:**
- `exit_code != 0` triggers `error make` in `mimic call`
- `returns` value becomes the error message
- Test can catch and verify error behavior

## Environment State Management

nu-mimic uses environment variables for state management:

### Registry Initialization

```nu
def --env ensure-registry [] {
    if '__NU_MIMIC_REGISTRY__' not-in ($env | columns) {
        $env.__NU_MIMIC_REGISTRY__ = {
            expectations: {}
            calls: {}
        }
    }
}
```

**Pattern: Lazy initialization**
- Check if env var exists
- Initialize with default structure if missing
- Used at start of every mimic operation

### Environment Function Requirements

Functions that modify the mock registry MUST use `--env`:

```nu
# ✅ CORRECT - preserves registry changes
export def --env "mimic register" [...] {
    $env.__NU_MIMIC_REGISTRY__.expectations = (...)
}

# ❌ WRONG - changes lost after function returns
export def "mimic register" [...] {
    $env.__NU_MIMIC_REGISTRY__.expectations = (...)
}
```

## Advanced Patterns

### Multiple Expectations for Same Command

```nu
with-mimic {
    # First call matches first expectation
    mimic register git {args: ['fetch'], times: 1, returns: 'fetching...'}
    
    # Second call matches second expectation
    mimic register git {args: ['fetch'], returns: 'already up to date'}
    
    git fetch  # 'fetching...'
    git fetch  # 'already up to date'
}
```

**Matching order:**
- First non-consumed expectation that matches args
- Once `times: 1` expectation is used, it's marked consumed and skipped
- Falls through to next matching expectation

### Partial Mocking

Mock only specific commands, let others pass through:

```nu
with-mimic {
    # Mock git, but not other commands
    mimic register git {args: "any", returns: 'mocked'}
    
    git status        # Mocked
    ls               # Real command runs
}
```

### Assertion Patterns

Common assertion patterns in tests:

```nu
# Equality
assert equal $expected $actual

# Custom assertions
if $result != $expected {
    error make {msg: $"Expected ($expected), got ($result)"}
}

# Verify structure
assert (($result | describe) == "record")
assert ("field" in ($result | columns))
```

## Best Practices

1. **Always use `with-mimic`** unless you need manual control
2. **Use specific matchers** - prefer exact/wildcard over "any" for better test clarity
3. **Test one thing** - each test function should verify one behavior
4. **Use `times` for critical calls** - verify important operations happen expected number of times
5. **Simulate errors** - test error handling paths with `exit_code`
6. **Clean test names** - use descriptive strings: "test feature does X when Y"
7. **Verify wrapped commands** - ensure `--env --wrapped` pattern for mocking externals
8. **Don't leak state** - `with-mimic` handles reset/verify automatically

## Common Pitfalls

### Missing `--env` Flag

```nu
# ❌ WRONG - registry changes lost
def "mimic register" [command: string, spec: record] {
    $env.__NU_MIMIC_REGISTRY__.expectations = (...)
}

# ✅ CORRECT
def --env "mimic register" [command: string, spec: record] {
    $env.__NU_MIMIC_REGISTRY__.expectations = (...)
}
```

### Forgetting `--wrapped` Flag

```nu
# ❌ WRONG - doesn't override external git
def --env git [...args] { mimic call 'git' $args }

# ✅ CORRECT
def --env --wrapped git [...args] { mimic call 'git' $args }
```

### Not Using Rest Parameters

```nu
# ❌ WRONG - only captures first arg
def --env --wrapped git [arg: string] { ... }

# ✅ CORRECT - captures all args
def --env --wrapped git [...args] { ... }
```

### Mismatched Expectations

```nu
# Register expectation
mimic register git {args: ['status', '--porcelain'], returns: 'clean'}

# ❌ Call with different args - ERROR
git status  # ERROR: No matching expectation

# ✅ Call with exact args
git status --porcelain  # Works
```

## Testing Checklist

When writing tests:

- [ ] Test function uses `--env` flag
- [ ] Test name is descriptive string
- [ ] Uses `with-mimic` for automatic cleanup
- [ ] Mocked commands use `--wrapped` flag
- [ ] Mocked commands capture `...args`
- [ ] Expectations match actual calls
- [ ] Critical calls have `times` verification
- [ ] Error paths tested with `exit_code`
- [ ] Test is isolated (no shared state)
- [ ] Assertions are clear and specific

## Example: Complete Test Suite

```nu
# tests/git-operations.nu
use nu-mimic *

export def --env "test git status returns clean state" [] {
    with-mimic {
        mimic register git {args: ['status', '--porcelain'], returns: ''}
        
        def --env --wrapped git [...args] { mimic call 'git' $args }
        
        let result = (check-git-clean)
        
        assert equal true $result
    }
}

export def --env "test git status returns dirty state" [] {
    with-mimic {
        mimic register git {args: ['status', '--porcelain'], returns: 'M file.txt'}
        
        def --env --wrapped git [...args] { mimic call 'git' $args }
        
        let result = (check-git-clean)
        
        assert equal false $result
    }
}

export def --env "test git push failure is handled" [] {
    with-mimic {
        mimic register git {
            args: ['push']
            exit_code: 1
            returns: 'remote rejected'
        }
        
        def --env --wrapped git [...args] { mimic call 'git' $args }
        
        let result = try {
            push-changes
            "success"
        } catch {
            "failed"
        }
        
        assert equal "failed" $result
    }
}

# Helper functions being tested
def check-git-clean [] {
    let status = (git status --porcelain | str trim)
    $status == ""
}

def push-changes [] {
    git push
}
```

## Reference Implementation

For complete implementation details, see:
- `modules/nu-mimic/mod.nu` - Core mocking framework
- `modules/nu-mimic/matchers.nu` - Matcher implementations
- `docs/nu-mimic.md` - Full documentation

## Related Skills

- **nushell-usage** - Core Nushell patterns and syntax
- **nushell-cli** - CLI/TUI patterns for interactive tests
- **nushell-structured-data** - Result patterns for test assertions
