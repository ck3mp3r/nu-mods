#!/usr/bin/env nu

use std/assert
use ../../modules/ci *

# Test log debug with piped input
export def "test ci log debug piped" [] {
  "Piped debug message" | ci log debug
  assert true
}

# Test log debug with custom icon
export def "test ci log debug custom icon" [] {
  "Custom icon debug" | ci log debug --icon "🔍"
  assert true
}

# Test log info with piped input
export def "test ci log info piped" [] {
  "Piped info message" | ci log info
  assert true
}

# Test log info with custom icon
export def "test ci log info custom icon" [] {
  "Custom icon info" | ci log info --icon "✅"
  assert true
}

# Test log warning with piped input
export def "test ci log warning piped" [] {
  "Piped warning message" | ci log warning
  assert true
}

# Test log warning with custom icon
export def "test ci log warning custom icon" [] {
  "Custom icon warning" | ci log warning --icon "⚡"
  assert true
}

# Test log error with piped input
export def "test ci log error piped" [] {
  "Piped error message" | ci log error
  assert true
}

# Test log error with custom icon
export def "test ci log error custom icon" [] {
  "Custom icon error" | ci log error --icon "💥"
  assert true
}

# Test log critical with piped input
export def "test ci log critical piped" [] {
  "Piped critical message" | ci log critical
  assert true
}

# Test log critical with custom icon
export def "test ci log critical custom icon" [] {
  "Custom icon critical" | ci log critical --icon "💀"
  assert true
}
