# Skill: nushell-cli

# Nushell CLI Subcommand Pattern

This skill covers the pattern for organizing Nushell commands into hierarchical CLI tools using `def main` and quoted subcommand names.

## The Core Pattern

### Basic Subcommand Structure

```nu
# Entry point
def main [] {
  help main
}

# Subcommands use quoted names with spaces
def "main create" [name: string] {
  mkdir $name
  print $"Created ($name)"
}

def "main delete" [name: string] {
  rm -r $name
  print $"Deleted ($name)"
}

def "main list" [] {
  ls | select name type size
}
```

**How it works:**
- `def main []` is the entry point
- Spaces in quoted names create subcommands: `"main create"`
- More spaces = deeper nesting: `"main sub subsub"`

**Usage:**
```bash
nu tool.nu              # Calls main, shows help
nu tool.nu create foo   # Calls "main create"
nu tool.nu list         # Calls "main list"
```

### Multi-Level Hierarchies

Add more spaces for deeper nesting:

```nu
def main [] {
  help main
}

# Level 1 - namespace stub
def "main repo" [] {
  help main repo
}

# Level 2 - actual commands
def "main repo create" [name: string] {
  git init $name
}

def "main repo clone" [url: string] {
  git clone $url
}

# Level 1 - another namespace
def "main config" [] {
  help main config
}

# Level 2 - actual commands
def "main config get" [key: string] {
  # Implementation
}

def "main config set" [key: string, value: string] {
  # Implementation
}
```

**Creates hierarchy:**
```
main
├── repo
│   ├── create
│   └── clone
└── config
    ├── get
    └── set
```

**Usage:**
```bash
nu tool.nu                    # Shows main help
nu tool.nu repo               # Shows repo help
nu tool.nu repo create myrepo # Runs command
nu tool.nu config get key     # Runs command
```

## Directory-Based Modules

For larger projects, split commands across multiple files using directory modules.

### Directory Structure

```
mytool/
├── mod.nu              # Entry point (required for directory modules)
├── database.nu         # Database subcommands
├── server.nu           # Server subcommands
└── utils.nu            # Utility subcommands
```

### mod.nu - The Entry Point

**Critical:** `mod.nu` is required for directory modules. When you `use mytool`, Nushell automatically loads `mytool/mod.nu`.

```nu
# Entry point
export def main [] {
  help main
}

# Re-export submodules
export use ./database.nu *
export use ./server.nu *
export use ./utils.nu *
```

**What this does:**
- `export def main []` - entry point when module is called
- `export use ./file.nu *` - makes all commands from that file available
- Without `mod.nu`, the directory won't be recognized as a module

### Submodule Files

Each file defines commands with the FULL hierarchy:

**database.nu:**
```nu
# Namespace stub
export def "main db" [] {
  help main db
}

# Full path from root in every command
export def "main db connect" [host: string] {
  # Implementation
}

export def "main db migrate" [] {
  # Implementation
}

export def "main db backup" [path: string] {
  # Implementation
}
```

**server.nu:**
```nu
# Namespace stub
export def "main server" [] {
  help main server
}

# Full path from root
export def "main server start" [--port: int = 8080] {
  # Implementation
}

export def "main server stop" [] {
  # Implementation
}
```

**Key points:**
- Use `export def` so mod.nu can re-export them
- Use FULL path from root: `"main db connect"` not just `"connect"`
- Commands in same file share the same prefix

### How It Works Together

1. User runs: `use mytool *`
2. Nushell loads `mytool/mod.nu`
3. `mod.nu` does `export use ./database.nu *`
4. Commands like `"main db connect"` become available
5. User can call: `main db connect localhost`

**Benefits:**
- **Organization:** Related commands in same file
- **Maintainability:** Easy to find and edit
- **Modularity:** Can test individual files
- **Scalability:** Add new files without changing structure

## Namespace Stubs

Commands without parameters can show help for that level:

```nu
def "main repo" [] {
  help main repo
}
```

This creates a "namespace" - calling it shows help instead of running logic.

**When to use:**
- Multi-level hierarchies
- Grouping related commands
- Providing help at each level

## Best Practices

### 1. Always Provide Main Entry

```nu
# ✅ Correct
def main [] {
  help main
}

# ❌ Wrong - no entry point
# (missing entirely)
```

### 2. Use Consistent Prefixes

All commands in a file should share the same prefix:

```nu
# ✅ Correct - consistent
def "main db connect" [] { }
def "main db migrate" [] { }
def "main db backup" [] { }

# ❌ Wrong - inconsistent
def "main db connect" [] { }
def "main migrate" [] { }      # Missing "db"
def "database backup" [] { }   # Wrong prefix
```

### 3. Use Full Paths in Submodules

When splitting across files, always use full path from root:

```nu
# ✅ Correct - full path
export def "main server start" [] { }

# ❌ Wrong - partial path
export def "server start" [] { }
```

### 4. Export in Submodules

```nu
# ✅ Correct - export so mod.nu can re-export
export def "main cmd" [] { }

# ❌ Wrong - not exported, won't be available
def "main cmd" [] { }
```

### 5. Use Relative Paths in mod.nu

```nu
# ✅ Correct - relative path
export use ./database.nu *

# ❌ Wrong - absolute path
export use ~/mytool/database.nu *
```

## Complete Example

**Directory structure:**
```
calculator/
├── mod.nu
├── basic.nu
└── scientific.nu
```

**mod.nu:**
```nu
export def main [] {
  help main
}

export use ./basic.nu *
export use ./scientific.nu *
```

**basic.nu:**
```nu
export def "main basic" [] {
  help main basic
}

export def "main basic add" [a: int, b: int] {
  $a + $b
}

export def "main basic subtract" [a: int, b: int] {
  $a - $b
}
```

**scientific.nu:**
```nu
export def "main sci" [] {
  help main sci
}

export def "main sci sqrt" [x: float] {
  $x ** 0.5
}

export def "main sci pow" [base: float, exp: float] {
  $base ** $exp
}
```

**Usage:**
```bash
use calculator *

main                        # Shows help
main basic                  # Shows basic help
main basic add 5 3          # Returns 8
main sci sqrt 16            # Returns 4
```

## Pattern Summary

**Single file:**
1. `def main []` - entry point
2. `def "main subcommand"` - subcommands with quoted names
3. Spaces create hierarchy

**Multi-file (directory module):**
1. Create directory with `mod.nu`
2. `mod.nu` has `export def main []` and `export use ./file.nu *`
3. Each file uses `export def "full path command"`
4. All commands use full path from root

## Checklist

- [ ] Entry point: `def main []` calls help
- [ ] Subcommands: Use quoted names with spaces
- [ ] Nesting: More spaces = deeper levels
- [ ] Directory module: Create `mod.nu` as entry point
- [ ] Re-exports: Use `export use ./file.nu *` in mod.nu
- [ ] Full paths: Commands in submodules use complete hierarchy
- [ ] Exports: Use `export def` in submodule files
- [ ] Consistency: Same prefix for related commands
- [ ] Namespace stubs: Commands that just show help

## Related Skills

- **nushell-usage** - Core Nushell patterns and syntax
- **nushell-testing** - Testing CLI commands
- **nushell-structured-data** - Record patterns for CLI outputs
