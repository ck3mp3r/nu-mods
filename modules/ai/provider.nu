# AI provider abstraction layer
# This module provides a simple interface to interact with AI providers
# Currently uses OpenCode CLI, but can be easily swapped for other providers

# Fixed session ID for git automation to avoid polluting session list
const SESSION_ID = "ai-git-automation"

# Run an AI prompt and return the response
# 
# # Arguments
# * `prompt` - The prompt to send to the AI
# * `model` - The model to use (in provider/model format, e.g., "anthropic/claude-3.5-sonnet")
#
# # Returns
# The AI response as a string, or an error if the call failed
export def run [
  prompt: string
  model: string
]: nothing -> string {
  let response = (opencode run --model $model --session $SESSION_ID $prompt | complete)

  # Check for errors in stderr first
  if ($response.stderr | str trim) != "" {
    error make {
      msg: "AI provider error"
      label: {
        text: $response.stderr
        span: (metadata $prompt).span
      }
    }
  }

  # Check for non-zero exit code
  if $response.exit_code != 0 {
    error make {
      msg: $"AI provider failed with exit code ($response.exit_code)"
      label: {
        text: "Command failed"
        span: (metadata $prompt).span
      }
    }
  }

  # Clean up the response by removing thinking tags if present
  let result = ($response.stdout | str trim | split row "</think>" | last | str trim)

  # Check if result is empty
  if $result == "" {
    error make {
      msg: "AI provider returned empty response"
      label: {
        text: "No output received from AI model"
        span: (metadata $model).span
      }
    }
  }

  $result
}
