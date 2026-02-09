# Calculator CLI Example

A working example demonstrating the Nushell CLI subcommand pattern.

## Structure

```
calculator/
├── mod.nu          # Entry point, re-exports submodules
├── basic.nu        # Basic arithmetic operations
└── scientific.nu   # Scientific operations
```

## Usage

From the examples directory:

```nu
use calculator *

# Show help
main
main basic
main sci

# Basic operations
main basic add 5 3           # Returns 8
main basic subtract 10 4     # Returns 6
main basic multiply 7 6      # Returns 42
main basic divide 10.0 2.0   # Returns 5.0

# Scientific operations
main sci sqrt 16             # Returns 4.0
main sci pow 2 8             # Returns 256.0
main sci factorial 5         # Returns 120
main sci log 100             # Returns 2.0
```

## Testing

```nu
# From the examples directory
use calculator *

# Test basic operations
assert ((main basic add 5 3) == 8)
assert ((main basic multiply 7 6) == 42)

# Test scientific operations
assert ((main sci sqrt 16) == 4)
assert ((main sci factorial 5) == 120)

print "All tests passed!"
```

## Pattern Demonstrated

1. **Entry point**: `mod.nu` with `export def main []`
2. **Re-exports**: `export use ./file.nu *` to make submodules available
3. **Namespace stubs**: `"main basic"` and `"main sci"` show help
4. **Full paths**: Commands use complete hierarchy from root
5. **Exports**: All commands use `export def` for re-export
6. **Consistency**: Commands in same file share prefix (`main basic`, `main sci`)
