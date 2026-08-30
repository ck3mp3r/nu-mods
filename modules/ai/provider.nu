# AI provider abstraction layer
# This module provides a simple interface to interact with AI providers
# 
# Run an AI prompt and return the response
# 
# # Arguments
# * `prompt` - The prompt to send to the AI
# * `model` - Optional model to use (in provider/model format, e.g., "anthropic/claude-3.5-sonnet"). Defaults to nu-agent's built-in default.
#
# # Returns
# The AI response as a string, or an error if the call failed
export def execute [
  prompt: string
  model?: string
  --tools: record = {}
  --permissions: record = {}
]: nothing -> string {
  let result = try {
    if ($model | is-not-empty) {
      $prompt | agent --model $model --quiet --tools $tools --permissions $permissions | get response
    } else {
      $prompt | agent --quiet --tools $tools --permissions $permissions | get response
    }
  } catch {|err|
    error make {
      msg: "AI provider error"
      label: {
        text: $err.msg
        span: (metadata $prompt).span
      }
    }
  }

  # Clean up the response by removing thinking tags if present
  let cleaned = ($result | str trim | split row "</thinking>" | last | str trim)

  # Check if result is empty
  if $cleaned == "" {
    error make {
      msg: "AI provider returned empty response"
      label: {
        text: "No output received from AI model"
        span: (metadata $prompt).span
      }
    }
  }

  $cleaned
}
