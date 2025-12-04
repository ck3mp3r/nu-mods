# Enhanced logging for CI workflows
# Wraps std log with pipe-only input and custom icons
#
# Usage: "message" | ci log <level> [--icon "emoji"]

use std log

# Default icons for each log level
const DEFAULT_ICONS = {
  debug: "🐛"
  info: "ℹ️"
  warning: "⚠️"
  error: "❌"
  critical: "🔥"
}

# Helper function to format log message with icon
def format-with-icon [
  level: string
  custom_icon?: string
]: [string -> string] {
  let msg = $in
  let icon = if ($custom_icon | is-empty) {
    $DEFAULT_ICONS | get $level
  } else {
    $custom_icon
  }
  $" ($icon) ($msg)"
}

# Log a debug message from piped input
#
# Examples:
#   > "Starting process" | ci log debug
#   > "Processing item" | ci log debug --icon "🔍"
export def "ci log debug" [
  --icon (-i): string # Custom icon to override the default debug icon
]: [string -> nothing] {
  let formatted = ($in | format-with-icon "debug" $icon)
  log debug $formatted
}

# Log an info message from piped input
#
# Examples:
#   > "Operation completed" | ci log info
#   > "Task finished successfully" | ci log info --icon "✅"
export def "ci log info" [
  --icon (-i): string # Custom icon to override the default info icon
]: [string -> nothing] {
  let formatted = ($in | format-with-icon "info" $icon)
  log info $formatted
}

# Log a warning message from piped input
#
# Examples:
#   > "Disk space low" | ci log warning
#   > "Deprecated function used" | ci log warning --icon "⚡"
export def "ci log warning" [
  --icon (-i): string # Custom icon to override the default warning icon
]: [string -> nothing] {
  let formatted = ($in | format-with-icon "warning" $icon)
  log warning $formatted
}

# Log an error message from piped input
#
# Examples:
#   > "Failed to open file" | ci log error
#   > "Connection timeout" | ci log error --icon "💥"
export def "ci log error" [
  --icon (-i): string # Custom icon to override the default error icon
]: [string -> nothing] {
  let formatted = ($in | format-with-icon "error" $icon)
  log error $formatted
}

# Log a critical message from piped input
#
# Examples:
#   > "System failure imminent" | ci log critical
#   > "Out of memory" | ci log critical --icon "💀"
export def "ci log critical" [
  --icon (-i): string # Custom icon to override the default critical icon
]: [string -> nothing] {
  let formatted = ($in | format-with-icon "critical" $icon)
  log critical $formatted
}
