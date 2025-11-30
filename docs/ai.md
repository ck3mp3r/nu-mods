# AI Module

AI-powered git operations for intelligent workflow automation.

## Installation

```bash
nix profile install github:ck3mp3r/nu-mods#ai
```

## Requirements

- [mods CLI](https://github.com/charmbracelet/mods) - AI integration

## Commands

### `ai git commit`

Generate conventional commit messages from staged changes.

**Usage:**
```nu
ai git commit [--model <model>]
```

**Options:**
- `--model` - AI model to use (default: from mods config)

**Features:**
- Analyzes `git diff --cached`
- Generates conventional commit format
- Interactive workflow: create/retry/edit/abort

**Example:**
```nu
git add .
ai git commit
ai git commit --model gpt-4
```

---

### `ai git create branch`

Create branches with AI-generated names from descriptions.

**Usage:**
```nu
ai git create branch [--prefix <prefix>] [--description <desc>] [--model <model>]
```

**Options:**
- `--prefix` - Ticket prefix (e.g., JIRA-123)
- `--description` - Feature description
- `--model` - AI model to use

**Features:**
- Generates kebab-case branch names
- Supports ticket prefixes
- Interactive prompts for missing info

**Example:**
```nu
ai git create branch --prefix "JIRA-123" --description "Add user login"
# Creates: JIRA-123/add-user-login

ai git create branch
# Prompts for description interactively
```

---

### `ai git create pr`

Generate PR titles and descriptions from branch diff.

**Usage:**
```nu
ai git create pr [--target <branch>] [--model <model>]
```

**Options:**
- `--target` - Target branch (default: main)
- `--model` - AI model to use

**Features:**
- Analyzes diff against target
- Generates title and description
- Extracts prefix from branch name
- Interactive workflow

**Example:**
```nu
ai git create pr --target develop
ai git create pr --model gpt-4
```

## Configuration

The AI module uses the mods CLI configuration:

```bash
# Configure mods
mods --settings

# Set default model
export MODS_MODEL=gpt-4
```

## Workflow Example

```nu
# 1. Create a feature branch
ai git create branch --prefix "FEAT-456" --description "Add dark mode"

# 2. Make changes and commit
git add .
ai git commit

# 3. Create PR
ai git create pr --target main
```

## Error Handling

- Checks for staged changes before commit
- Validates git repository
- Handles mods CLI errors gracefully
- Provides clear error messages
