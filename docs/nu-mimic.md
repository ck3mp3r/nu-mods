# nu-mimic: Mimicing Framework for Nushell

A lightweight, environment-based mocking framework for testing Nushell code.

## Quick Start

```nushell
use modules/nu-mimic *

# 1. Setup expectations
mimic register git {
  args: ['status']
  returns: 'clean'
}

# 2. Create wrapper using --wrapped
def --env --wrapped git [...args] {
  mimic call 'git' $args
}

# 3. Use naturally
git status  # Returns 'clean'

# 4. Verify
mimic verify
```

## Core Concepts

### Framework Philosophy

nu-mimic is a **framework**, not a collection of pre-made mocks. It provides:
- Primitives for registering expectations
- Argument matching system
- Call verification
- **You create the wrappers** for commands you want to mock

### Why `--wrapped`?

The `--wrapped` flag tells Nushell to shadow the external command with your wrapper:

```nushell
def --env --wrapped git [...args] { mimic call 'git' $args }
```

Without `--wrapped`, your wrapper won't properly shadow the external `git` command.

## API Reference

### `mimic register`

Register an expectation for a function call.

```nushell
mimic register <function_name> <spec>
```

**Spec fields:**
- `args: list` - Arguments to match (required)
- `returns: any` - Value to return (required)
- `times: int` - How many times this should be called (optional, default: 1)
- `exit_code: int` - Exit code to simulate (optional, default: 0)

**Examples:**

```nushell
# Basic expectation
mimic register git {
  args: ['status']
  returns: 'nothing to commit'
}

# Multiple calls
mimic register curl {
  args: ['https://api.example.com']
  returns: '{"status":"ok"}'
  times: 3
}

# Error simulation
mimic register git {
  args: ['push']
  returns: 'fatal: remote error'
  exit_code: 1
}
```

### `mimic call`

Execute a mocked function call. **Use this in your wrapper functions.**

```nushell
mimic call <function_name> <args>
```

This will:
1. Find matching expectation
2. Record the call
3. Return the mocked value
4. Error if `exit_code != 0`

**Example:**

```nushell
def --env --wrapped git [...args] {
  mimic call 'git' $args
}
```

### `mimic verify`

Verify all expectations were met (called correct number of times).

```nushell
mimic verify
```

Errors if any expectation wasn't satisfied. Call this at the end of your test.

### `mimic reset`

Clear all expectations and call history. **Always call this at the start of each test.**

```nushell
mimic reset
```

### `mimic get-calls`

Get all recorded calls for a function (for advanced assertions).

```nushell
mimic get-calls <function_name>
```

Returns list of call records: `[{args: [...]}, ...]`

## Argument Matching

### Exact Match

```nushell
mimic register git {
  args: ['status', '--short']
  returns: 'M file.txt'
}
```

Matches only if arguments are exactly `['status', '--short']`.

### Wildcard Match

Use `_` to match any single value:

```nushell
mimic register git {
  args: ['commit', '-m', _]  # Any commit message
  returns: '[main abc123]'
}
```

### Any Match

Use special `{any: true}` for the entire args list:

```nushell
mimic register git {
  args: {any: true}  # Matches ANY git call
  returns: 'mocked'
}
```

### Contains Match

Match if argument list contains specific values:

```nushell
mimic register curl {
  args: {contains: 'api.example.com'}
  returns: '{"ok":true}'
}
```

### Regex Match

Match arguments with regex patterns:

```nushell
mimic register git {
  args: {regex: '^commit.*'}
  returns: 'committed'
}
```

## Complete Example

```nushell
use modules/nu-mimic *

export def --env "test git workflow" [] {
  # Setup
  mimic reset
  
  # Register expectations
  mimic register git {
    args: ['status']
    returns: 'clean'
    times: 2
  }
  
  mimic register git {
    args: ['push']
    returns: 'success'
  }
  
  # Create wrapper
  def --env --wrapped git [...args] {
    mimic call 'git' $args
  }
  
  # Run code under test
  def --env my_workflow [] {
    let s1 = (git status)
    let s2 = (git status)
    git push
    
    {status1: $s1, status2: $s2}
  }
  
  let results = (my_workflow)
  
  # Assertions
  assert ($results.status1 == 'clean')
  assert ($results.status2 == 'clean')
  
  # Verify all expectations met
  mimic verify
}
```

## Sequential Expectations

Register multiple expectations for the same function - they're consumed in order:

```nushell
# First call returns 'first'
mimic register git {
  args: ['status']
  returns: 'first'
  times: 1
}

# Second call returns 'second'
mimic register git {
  args: ['status']
  returns: 'second'
  times: 1
}

def --env --wrapped git [...args] { mimic call 'git' $args }

git status  # Returns 'first'
git status  # Returns 'second'
```

## Error Handling

Simulate command failures with `exit_code`:

```nushell
mimic register git {
  args: ['push']
  returns: 'fatal: authentication failed'
  exit_code: 128
}

def --env --wrapped git [...args] { mimic call 'git' $args }

# This will error
try {
  git push
} catch { |e|
  print "Caught error!"
}
```

## Best Practices

### 1. Always Reset at Test Start

```nushell
export def --env "test something" [] {
  mimic reset  # CRITICAL!
  # ... rest of test
}
```

### 2. Create Wrappers Per Test

Don't create global wrappers - create them inside each test function:

```nushell
export def --env "test my feature" [] {
  mimic reset
  
  # Define wrapper HERE
  def --env --wrapped git [...args] { mimic call 'git' $args }
  
  # ... test code
}
```

### 3. Use Specific Matchers

Prefer exact matches over wildcards when possible:

```nushell
# Good
mimic register git { args: ['status', '--short'], returns: 'M file.txt' }

# Less good (too permissive)
mimic register git { args: {any: true}, returns: 'whatever' }
```

### 4. Verify at the End

Always call `mimic verify` to ensure all expectations were satisfied:

```nushell
export def --env "test something" [] {
  mimic reset
  mimic register some_cmd { args: ['test'], returns: 'ok', times: 2 }
  
  # ... test code that should call some_cmd twice
  
  mimic verify  # Will error if called != 2 times
}
```

## Implementation Details

### Storage

Mimics are stored in `$env.__NU_MOCK_REGISTRY__`:

```nushell
{
  expectations: {
    "git": [{args: [...], returns: "...", times: 1}]
  }
  calls: {
    "git": [{args: [...]}]
  }
}
```

### Matcher System

Matchers are applied in order of specificity:
1. Exact match
2. Wildcard match (`_`)
3. Any match (`{any: true}`)
4. Contains match (`{contains: ...}`)
5. Regex match (`{regex: ...}`)

See `modules/nu-mimic/matchers.nu` for matcher implementation.

## Testing the Framework

The framework is self-tested! See `tests/nu-mimic/`:
- `test_registry.nu` - Core registration/lookup
- `test_matchers.nu` - Argument matching
- `test_call_tracking.nu` - Call recording and verification
- `test_integration.nu` - Full workflow tests
- `test_proper_usage.nu` - Usage examples

Run tests:

```bash
nu run_tests.nu
```

## Limitations

1. **No automatic cleanup** - You must call `mimic reset` in each test
2. **Environment-based** - Mimic state is in `$env`, so wrappers must use `--env`
3. **Manual wrappers** - You create your own `--wrapped` functions per test
4. **Single process** - Doesn't work across subprocess boundaries (except when intentional)

## Contributing

When adding matchers:
1. Add matcher function to `modules/nu-mimic/matchers.nu`
2. Export the matcher
3. Add to the matcher precedence in `matcher apply`
4. Add tests in `tests/nu-mimic/test_matchers.nu`

Follow TDD - test first!
