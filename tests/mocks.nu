# Mock wrapper functions for external commands
# These check for NU_TEST_MODE and use MOCK_* environment variables
# IMPORTANT: These should ONLY be used in tests, never in production code

# Mock git command - returns just the output string
export def --wrapped git [...rest] {
  let args = ($rest | str join "_" | str replace --all " " "_" | str replace --all "/" "_")
  let mock_var = $"MOCK_git_($args)"

  if $mock_var in $env {
    let mock_data = ($env | get $mock_var | from json)
    if $mock_data.exit_code != 0 {
      error make {msg: $"Git error: ($mock_data.output)"}
    }
    $mock_data.output
  } else {
    error make {msg: $"Mock not found: ($mock_var)"}
  }
}

# Mock gh command - returns just the output string
export def --wrapped gh [...rest] {
  let args = ($rest | str join "_" | str replace --all " " "_" | str replace --all "/" "_")
  let mock_var = $"MOCK_gh_($args)"

  if $mock_var in $env {
    let mock_data = ($env | get $mock_var | from json)
    if $mock_data.exit_code != 0 {
      error make {msg: $"GitHub CLI error: ($mock_data.output)"}
    }
    $mock_data.output
  } else {
    error make {msg: $"Mock not found: ($mock_var)"}
  }
}

# Mock opencode command
# Validates model and prompt parameters, and can check prompt content
export def --wrapped opencode [...rest] {
  # Extract command, model, and prompt
  let cmd = ($rest | first)
  let model_idx = ($rest | enumerate | where {|x| $x.item == "--model" } | first | get index)
  let model = if $model_idx != null {
    $rest | get ($model_idx + 1)
  } else {
    "unknown"
  }

  # Get the prompt (last argument)
  let prompt = ($rest | last)

  # Check for suspicious hardcoded prompts
  let suspicious = ["meh" "foo" "test" "bar" "hardcoded"]
  if $prompt in $suspicious {
    error make {msg: $"Suspicious hardcoded prompt detected: ($prompt)"}
  }

  # Check if prompt is too short (likely hardcoded)
  if ($prompt | str length) < 10 {
    error make {msg: $"Prompt too short, likely hardcoded: ($prompt)"}
  }

  # Check if there are expected keywords in the prompt (if specified)
  let expected_keywords_var = $"MOCK_opencode_expected_keywords"
  if $expected_keywords_var in $env {
    let expected = ($env | get $expected_keywords_var | from json)
    for keyword in $expected {
      if ($prompt | str contains $keyword | not $in) {
        error make {msg: $"Expected prompt to contain '($keyword)' but it didn't. Prompt: ($prompt)"}
      }
    }
  }

  let mock_var = $"MOCK_opencode_($cmd)_--model_($model)"

  if $mock_var in $env {
    let mock_data = ($env | get $mock_var | from json)
    $mock_data.output
  } else {
    error make {msg: $"Mock not found: ($mock_var)"}
  }
}

# Mock input command
# Just returns a default value based on context - always returns "a" for abort
export def --wrapped input [...rest] {
  # Check if there's a specific mock for this input call
  let args = ($rest | str join "_" | str replace --all " " "_")
  let specific_mock = $"MOCK_input_($args)"

  if $specific_mock in $env {
    let mock_data = ($env | get $specific_mock | from json)
    $mock_data.output
  } else if "MOCK_input" in $env {
    # Fallback to generic mock
    let mock_data = ($env | get "MOCK_input" | from json)
    $mock_data.output
  } else {
    # Default: abort
    "a"
  }
}

# Mock nix command - returns just the output string
export def --wrapped nix [...rest] {
  let args = ($rest | str join "_" | str replace --all " " "_" | str replace --all "/" "_")
  let mock_var = $"MOCK_nix_($args)"

  if $mock_var in $env {
    let mock_data = ($env | get $mock_var | from json)
    if $mock_data.exit_code != 0 {
      error make {msg: $"Nix error: ($mock_data.output)"}
    }
    $mock_data.output
  } else {
    error make {msg: $"Mock not found: ($mock_var)"}
  }
}
