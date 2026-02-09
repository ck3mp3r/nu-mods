---
name: nushell-shell
description: Use Nushell as a shell including redirection, pipes, environment variables, external commands, and critical differences from bash/zsh. CRITICAL for avoiding bash/zsh syntax mistakes.
---

# Nushell Shell Patterns

This skill covers using Nushell as a shell, including redirection, pipes, environment variables, external commands, and critical differences from bash/zsh.

## 🚨 CRITICAL: Redirection Differences

### Bash vs Nushell Redirection

**MOST COMMON MISTAKE:** Using bash syntax in Nushell

| Bash/Zsh | Nushell | Purpose |
|----------|---------|---------|
| `cmd 2>&1` | `cmd out+err>|` or `cmd o+e>|` | Combine stdout+stderr to pipeline |
| `cmd 2>&1 \| less` | `cmd o+e>\| less` | Pipe both streams |
| `cmd > file 2>&1` | `cmd out+err> file` or `cmd o+e> file` | Redirect both to file |
| `cmd 2> /dev/null` | `cmd err> /dev/null` or `cmd e> /dev/null` | Suppress stderr |
| `cmd > /dev/null 2>&1` | `cmd o+e>\| ignore` | Discard all output |
| `cmd > out.log 2> err.log` | `cmd out> out.log err> err.log` | Separate files |

### Redirection Operators

**Stdout only:**
```nu
cmd out> file.txt      # Redirect stdout to file
cmd o> file.txt        # Short form
cmd out>| next-cmd     # Pipe stdout to next command
```

**Stderr only:**
```nu
cmd err> error.log     # Redirect stderr to file
cmd e> error.log       # Short form
cmd err>| next-cmd     # Pipe stderr to next command
```

**Combined stdout+stderr:**
```nu
cmd out+err> all.log   # Redirect both to file
cmd o+e> all.log       # Short form
cmd out+err>| next-cmd # Pipe both to next command
cmd o+e>| next-cmd     # Short form
```

### Common Redirection Patterns

```nu
# Suppress errors
git status err> /dev/null

# Or use std null-device for cross-platform
use std
git status e> (std null-device)

# Capture all output
let output = (command o+e>| str collect)

# Discard all output
command o+e>| ignore

# Process errors separately
command e>| str upcase
```

## External Commands

### Running External Commands

```nu
# Explicit external command (recommended)
^ls
^git status
^npm install

# External commands in subexpressions
let files = (^ls /tmp)

# Passing Nushell data to external commands
ls | get name | to text | ^grep pattern
```

**Why use `^`:**
- Makes it clear it's not a Nushell command
- Avoids ambiguity (Nushell has its own `ls`, `find`, etc.)
- Nushell commands always have precedence

### Wrapped External Commands

Override external commands with custom logic:

```nu
# Wrap ls with custom behavior
def --wrapped ls [...rest] {
  ^ls -l ...$rest
}

# Now 'ls' calls your wrapper
ls        # Runs your wrapper with -l flag
```

**Key elements:**
- `--wrapped` flag tells Nushell you're shadowing an external command
- `...rest` captures all arguments
- `...$rest` spreads them to external command

### Getting Exit Codes

```nu
# Using complete (recommended for external commands)
let result = (^command | complete)
if $result.exit_code != 0 {
  print $"Error: ($result.stderr)"
}

# Using $env.LAST_EXIT_CODE
do { ^command }
if $env.LAST_EXIT_CODE != 0 {
  print "Command failed"
}

# In try-catch
try {
  ^command e> /dev/null
} catch {|e|
  print $e.exit_code
}
```

**The `complete` command:**
```nu
^cat unknown.txt | complete
# Returns: {
#   stdout: ""
#   stderr: "cat: unknown.txt: No such file or directory"
#   exit_code: 1
# }
```

## Environment Variables

### Setting Environment Variables

```nu
# Set for current session
$env.FOO = "BAR"

# Temporary for one command
FOO=BAR command

# Temporary for block
with-env {FOO: "BAR"} {
  $env.FOO  # "BAR"
}
# $env.FOO not set here
```

### Reading Environment Variables

```nu
# Direct access
$env.PATH
$env.HOME

# Safe access (returns null if not set)
$env.OPTIONAL_VAR?

# With default
$env.OPTIONAL_VAR? | default "default_value"

# Check if exists
if "VAR" in ($env | columns) {
  # Variable exists
}
```

### Unsetting Environment Variables

```nu
# Remove from current session
hide-env FOO

# Check if removed
$env.FOO?  # null
```

### Path Manipulation

```nu
# Add to PATH (prepend - higher priority)
$env.Path = ($env.Path | prepend '/usr/local/bin')

# Add to PATH (append - lower priority)
$env.Path = ($env.Path | append '/opt/bin')

# Remove from PATH
$env.Path = ($env.Path | where $it != '/unwanted/path')
```

## 🚨 Common Bash Patterns to Avoid

### Command Chaining

```nu
# ❌ WRONG - Nushell does NOT support &&
cmd1 && cmd2

# ✅ CORRECT - Use semicolon
cmd1; cmd2

# ✅ CORRECT - Stop on error with try
try { cmd1 }
cmd2
```

### OR Operator

```nu
# ❌ WRONG - Nushell does NOT support ||
cmd1 || cmd2

# ✅ CORRECT - Use try-catch
try { cmd1 } catch { cmd2 }
```

### Redirection

```nu
# ❌ WRONG - bash syntax
command 2>&1
command > file 2>&1
command 2> /dev/null

# ✅ CORRECT - Nushell syntax
command o+e>|
command o+e> file
command e> /dev/null
```

### Output Filtering

```nu
# ❌ WRONG - external commands
command | tail -20
command | head -10
command | grep pattern

# ✅ CORRECT - Nushell commands (when working with Nushell data)
command | last 20
command | first 10
command | find pattern

# ✅ ALSO CORRECT - explicit external (for text processing)
command | lines | ^grep pattern
```

### Variable Export

```nu
# ❌ WRONG - bash syntax
export VAR=value

# ✅ CORRECT - Nushell syntax
$env.VAR = "value"
```

## Pipes and Redirection Scope

### Pipe Scope

Redirections only affect the immediate command:

```nu
# Only 'cmd2' is redirected
(cmd1; cmd2) o+e>| cmd3

# Both redirected (separate expressions)
cmd1 o+e>| cmd3
cmd2 o+e>| cmd3
```

### Expression Redirection

Redirect entire expression output:

```nu
# Redirect both commands to file
let text = "hello\nworld"
($text | head -n 1; $text | tail -n 1) o> out.txt
```

## Pipeline vs External Output

### Nushell Pipelines

```nu
# Nushell commands return structured data
ls | where size > 1mb | select name size

# Data flows as tables/records
ps | where cpu > 50 | get name
```

### External Commands

```nu
# External commands output text
^ls | lines | find ".txt"

# Need to convert for external tools
ls | get name | to text | ^grep pattern

# Or use explicit external
^ls | ^grep pattern
```

## Environment in Functions

### Persistent Environment Changes

```nu
# ❌ Changes don't persist
def set-var [] {
  $env.FOO = "bar"
}
set-var
$env.FOO  # Error - not set

# ✅ Changes persist with --env
def --env set-var [] {
  $env.FOO = "bar"
}
set-var
$env.FOO  # "bar"
```

### Scoped Changes

```nu
# Changes scoped to block
do {
  $env.TEMP = "value"
  # TEMP is set here
}
# TEMP not set here

# Explicitly scoped with --env
do --env {
  $env.TEMP = "value"
  # TEMP is set here
}
# TEMP IS set here because of --env
```

## Quick Reference Table

### Most Common Mistakes

| ❌ Bash/Zsh (WRONG) | ✅ Nushell (CORRECT) | What It Does |
|---------------------|---------------------|--------------|
| `cmd1 && cmd2` | `cmd1; cmd2` | Run sequentially |
| `cmd1 \|\| cmd2` | `try { cmd1 } catch { cmd2 }` | Fallback on error |
| `cmd 2>&1` | `cmd o+e>\|` | Combine streams |
| `cmd > file 2>&1` | `cmd o+e> file` | Redirect both to file |
| `cmd 2> /dev/null` | `cmd e> /dev/null` | Suppress stderr |
| `cmd \| tail -20` | `cmd \| last 20` | Last 20 items |
| `cmd \| head -10` | `cmd \| first 10` | First 10 items |
| `export VAR=val` | `$env.VAR = "val"` | Set env var |
| `echo $VAR` | `$env.VAR` | Read env var |
| `unset VAR` | `hide-env VAR` | Remove env var |

## Best Practices

### 1. Use Explicit External Commands

```nu
# ✅ Clear intent
^grep pattern file.txt
^find . -name "*.nu"

# ❌ Ambiguous - is it Nushell's find?
find pattern
```

### 2. Use Proper Redirection

```nu
# ✅ Correct
command o+e>| str upcase

# ❌ Wrong - bash syntax doesn't work
command 2>&1 | str upcase
```

### 3. Use Complete for External Commands

```nu
# ✅ Full error information
let result = (^git push | complete)
if $result.exit_code != 0 {
  print $"Error: ($result.stderr)"
}

# ❌ Less information
try { ^git push } catch {|e|
  # Only get exit code
}
```

### 4. Prefix External with Caret

```nu
# ✅ Clear it's external
^ls
^grep
^git

# ❌ Could be Nushell command
ls    # This is Nushell's ls, not /bin/ls
```

### 5. Convert Data for External Commands

```nu
# ✅ Convert to text for external tools
ls | get name | to text | ^grep pattern

# ❌ Pass structured data (won't work)
ls | get name | ^grep pattern
```

## Checklist

- [ ] Use `o+e>|` not `2>&1` for combining streams
- [ ] Use `;` not `&&` for sequential commands
- [ ] Use `^` prefix for external commands
- [ ] Use `complete` to get exit codes from external commands
- [ ] Use `$env.VAR` not `$VAR` for environment variables
- [ ] Use `--env` flag for persistent environment changes
- [ ] Use `hide-env` not `unset` to remove variables
- [ ] Convert Nushell data to text before piping to external commands
- [ ] Use proper redirection operators (`out>`, `err>`, `o+e>`)
- [ ] Use Nushell commands (`last`, `first`) instead of external (`tail`, `head`)

## Related Skills

- **nushell-usage** - Core Nushell patterns and syntax
- **nushell-testing** - Testing shell commands
- **nushell-cli** - Building CLI tools
- **nushell-structured-data** - Working with records and data
