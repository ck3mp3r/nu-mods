---
name: nushell-structured-data
description: Work with structured data in Nushell including records, error handling, validation, and consistent return values. Use when handling data structures, implementing error patterns, or building robust data pipelines.
---

# Nushell Structured Data Patterns

This skill covers patterns for working with structured data in Nushell, including records, error handling, validation, and consistent return values.

## Record Patterns

### Creating Records

```nu
# Basic record
let config = {
  name: "myapp"
  version: "1.0.0"
  port: 8080
}

# Record with nested data
let user = {
  name: "Alice"
  email: "alice@example.com"
  settings: {
    theme: "dark"
    notifications: true
  }
}

# Record from variables
let name = "Bob"
let age = 30
let person = {
  name: $name
  age: $age
}
```

### Accessing Record Fields

```nu
# Direct access
$config.name          # "myapp"
$config.port          # 8080

# Nested access
$user.settings.theme  # "dark"

# Using get command
$config | get name    # "myapp"

# Optional access (returns null if missing)
$config.missing?      # null
$config.port?         # 8080

# With default value
$config.missing? | default "N/A"  # "N/A"
```

### Modifying Records

```nu
# Insert new field
$config | insert env "production"

# Update existing field
$config | update port 3000

# Upsert (update or insert)
$config | upsert debug false

# Reject fields (remove)
$user | reject email

# Select specific fields
$user | select name email
```

## Structured Return Pattern

### Standard Result Record

**Pattern:** Always return a record with consistent fields for programmatic handling.

```nu
# Success result
{
  status: "success"
  error: null
  data: $result
}

# Error result  
{
  status: "error"
  error: "Description of what went wrong"
  data: null
}
```

### Real-World Example

```nu
export def "process file" [path: string]: nothing -> record {
  # Validate input
  if not ($path | path exists) {
    return {
      status: "error"
      error: $"File not found: ($path)"
      data: null
    }
  }
  
  # Try operation
  let result = try {
    open $path | from json
  } catch {|err|
    return {
      status: "error"
      error: $"Failed to parse JSON: ($err.msg)"
      data: null
    }
  }
  
  # Success
  {
    status: "success"
    error: null
    data: $result
  }
}
```

### Operation-Specific Fields

Add operation-specific data alongside standard fields:

```nu
# Git branch creation
{
  status: "success"
  error: null
  branch: "feature/new-feature"
  rebased: false
}

# Configuration update
{
  status: "success"
  error: null
  name: "john"
  email: "john@example.com"
  scope: "global"
}

# File processing with stats
{
  status: "success"
  error: null
  processed: 42
  skipped: 3
  failed: 0
}
```

## Error Handling

### Creating Errors

```nu
# Simple error
error make {msg: "Something went wrong"}

# Error with detailed info
error make {
  msg: "Invalid configuration"
  label: {
    text: "value must be positive"
    span: (metadata $value).span
  }
}
```

### Try-Catch Pattern

```nu
# Basic try-catch
try {
  risky-operation
} catch {|err|
  print $"Error: ($err.msg)"
}

# With return value
let result = try {
  parse-data $input
} catch {
  null  # Return null on error
}

# Check for null
if $result == null {
  # Handle error case
}
```

### Structured Error Returns

```nu
def safe-operation []: nothing -> record {
  try {
    # Do work
    dangerous-thing
    
    {status: "success", error: null, result: $data}
  } catch {|err|
    {status: "error", error: $err.msg, result: null}
  }
}
```

## Validation Patterns

### Input Validation

```nu
export def "create user" [
  name: string
  email: string
  --age: int
]: nothing -> record {
  # Required field validation
  if $name == "" {
    return {
      status: "error"
      error: "Name cannot be empty"
      user: null
    }
  }
  
  # Format validation
  if not ($email | str contains "@") {
    return {
      status: "error"
      error: "Invalid email format"
      user: null
    }
  }
  
  # Range validation
  if $age != null and ($age < 0 or $age > 150) {
    return {
      status: "error"
      error: "Age must be between 0 and 150"
      user: null
    }
  }
  
  # All valid - create user
  {
    status: "success"
    error: null
    user: {name: $name, email: $email, age: $age}
  }
}
```

### Validation Helper Pattern

```nu
def validate-email [email: string]: nothing -> record {
  if not ($email | str contains "@") {
    return {valid: false, error: "Must contain @"}
  }
  
  if not ($email | str contains ".") {
    return {valid: false, error: "Must contain domain"}
  }
  
  {valid: true, error: null}
}

# Usage
let validation = (validate-email $input)
if not $validation.valid {
  return {status: "error", error: $validation.error}
}
```

## Optional Fields and Null Handling

### Optional Field Access

```nu
# Safe access with ?
let value = $record.field?

# Check if null
if $value == null {
  print "Field not found"
}

# Provide default
let value = $record.field? | default "default_value"

# Chain optional access
$record.nested?.deep?.field?
```

### Default Values

```nu
# Use default command
$record | default "N/A" missing_field

# Use conditional
let value = if "field" in ($record | columns) {
  $record.field
} else {
  "default"
}

# Use optional with default
let value = $record.field? | default "default"
```

## Working with Lists of Records

### Filtering

```nu
# Filter by field value
$users | where age > 18

# Filter by multiple conditions
$users | where age > 18 and status == "active"

# Filter with complex logic
$users | where {|u|
  $u.age > 18 and ($u.email | str contains "@company.com")
}
```

### Transforming

```nu
# Add field to each record
$users | insert verified true

# Update field in each record
$users | update age {|u| $u.age + 1}

# Upsert field
$users | upsert status {|u|
  if $u.age >= 18 { "adult" } else { "minor" }
}

# Select specific fields
$users | select name email
```

### Grouping and Aggregating

```nu
# Group by field
$orders | group-by status

# Count by group
$orders | group-by status | each {|group| $group.items | length}

# Aggregate
$orders | reduce {|it, acc|
  $acc + $it.total
}
```

## Type Signatures

### Declaring Input/Output Types

```nu
# String input, record output
def parse-config []: string -> record {
  $in | from json
}

# Record input, string output
def format-user []: record -> string {
  $"($in.name) <($in.email)>"
}

# Multiple input types
def process []: [
  string -> record
  record -> record
  nothing -> record
] {
  # Handle different input types
}
```

### Type Checking

```nu
# Check type at runtime
let data_type = $data | describe

if ($data_type | str starts-with "record") {
  # Handle record
} else if $data_type == "string" {
  # Handle string
}
```

## Best Practices

### 1. Consistent Status Field

```nu
# ✅ Consistent - always use same values
{status: "success", error: null}
{status: "error", error: "message"}

# ❌ Inconsistent - different status values
{status: "ok", error: null}
{status: "failed", error: "message"}
```

### 2. Always Include Error Field

```nu
# ✅ Correct - error field present
{status: "success", error: null, data: $result}
{status: "error", error: "Failed", data: null}

# ❌ Wrong - missing error field
{status: "success", data: $result}
{status: "error", message: "Failed"}  # Wrong field name
```

### 3. Validate Early

```nu
# ✅ Correct - validate first
if $input == "" {
  return {status: "error", error: "Input required"}
}
let result = process $input

# ❌ Wrong - process then validate
let result = process $input
if $input == "" {
  return {status: "error", error: "Input required"}
}
```

### 4. Use Optional Access for Uncertain Fields

```nu
# ✅ Correct - use ? for optional fields
let value = $record.optional_field?

# ❌ Wrong - will error if missing
let value = $record.optional_field
```

### 5. Provide Meaningful Error Messages

```nu
# ✅ Correct - specific, actionable
return {
  status: "error"
  error: "Email must contain '@' character"
}

# ❌ Wrong - vague
return {
  status: "error"
  error: "Invalid input"
}
```

## Common Patterns

### Check Field Exists

```nu
if "field_name" in ($record | columns) {
  # Field exists
}
```

### Merge Records

```nu
# Right-biased merge (right values win)
$record1 | merge $record2

# Merge many records
[$rec1 $rec2 $rec3] | into record
```

### Transform Record to Table

```nu
# Transpose for iteration
$record | transpose key value
```

### Null-Safe Pipeline

```nu
# Use optional and default
$data
| get field?
| default "fallback"
| str upcase
```

## Real-World Example

Complete function with validation, error handling, and structured returns:

```nu
export def "git create-branch" [
  description: string
  --prefix: string
  --from: string = "main"
]: nothing -> record {
  # Validate required input
  if ($description | str trim) == "" {
    return {
      status: "error"
      error: "Description is required"
      branch: null
    }
  }
  
  # Verify git repository
  try {
    git status --porcelain | ignore
  } catch {|err|
    return {
      status: "error"
      error: $"Not in a git repository: ($err.msg)"
      branch: null
    }
  }
  
  # Build branch name
  let clean_desc = (
    $description
    | str downcase
    | str replace --all ' ' '-'
    | str replace --all --regex '[^a-z0-9\-]' ''
  )
  
  let branch_name = if ($prefix | is-not-empty) {
    $"($prefix)/feature/($clean_desc)"
  } else {
    $"feature/($clean_desc)"
  }
  
  # Create branch
  try {
    git switch -c $branch_name
    {
      status: "success"
      error: null
      branch: $branch_name
      from: $from
    }
  } catch {|err|
    {
      status: "error"
      error: $"Failed to create branch: ($err.msg)"
      branch: null
    }
  }
}
```

## Checklist

- [ ] Return records with `status` and `error` fields
- [ ] Use consistent status values ("success", "error")
- [ ] Set `error: null` on success
- [ ] Add operation-specific fields as needed
- [ ] Validate inputs early and return errors
- [ ] Use `?` for optional field access
- [ ] Provide default values with `default`
- [ ] Use try-catch for operations that might fail
- [ ] Return meaningful error messages
- [ ] Declare type signatures for clarity

## Related Skills

- **nushell-usage** - Core Nushell patterns and syntax
- **nushell-testing** - Testing functions that return records
- **nushell-cli** - CLI commands that return structured data
