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

# Log a debug message from piped input
#
# Examples:
#   > "Starting process" | ci log debug
#   > "Processing item" | ci log debug --icon "🔍"
export def "ci log debug" [
  --icon (-i): string # Custom icon to override the default debug icon
]: [string -> nothing] {
  let msg = $in

  let icon = if ($icon | is-empty) {
    $DEFAULT_ICONS.debug
  } else {
    $icon
  }

  log debug $" ($icon) ($msg)"
}

# Log an info message from piped input
#
# Examples:
#   > "Operation completed" | ci log info
#   > "Task finished successfully" | ci log info --icon "✅"
export def "ci log info" [
  --icon (-i): string # Custom icon to override the default info icon
]: [string -> nothing] {
  let msg = $in

  let icon = if ($icon | is-empty) {
    $DEFAULT_ICONS.info
  } else {
    $icon
  }

  log info $" ($icon) ($msg)"
}

# Log a warning message from piped input
#
# Examples:
#   > "Disk space low" | ci log warning
#   > "Deprecated function used" | ci log warning --icon "⚡"
export def "ci log warning" [
  --icon (-i): string # Custom icon to override the default warning icon
]: [string -> nothing] {
  let msg = $in

  let icon = if ($icon | is-empty) {
    $DEFAULT_ICONS.warning
  } else {
    $icon
  }

  log warning $" ($icon) ($msg)"
}

# Log an error message from piped input
#
# Examples:
#   > "Failed to open file" | ci log error
#   > "Connection timeout" | ci log error --icon "💥"
export def "ci log error" [
  --icon (-i): string # Custom icon to override the default error icon
]: [string -> nothing] {
  let msg = $in

  let icon = if ($icon | is-empty) {
    $DEFAULT_ICONS.error
  } else {
    $icon
  }

  log error $" ($icon) ($msg)"
}

# Log a critical message from piped input
#
# Examples:
#   > "System failure imminent" | ci log critical
#   > "Out of memory" | ci log critical --icon "💀"
export def "ci log critical" [
  --icon (-i): string # Custom icon to override the default critical icon
]: [string -> nothing] {
  let msg = $in

  let icon = if ($icon | is-empty) {
    $DEFAULT_ICONS.critical
  } else {
    $icon
  }

  log critical $" ($icon) ($msg)"
}
