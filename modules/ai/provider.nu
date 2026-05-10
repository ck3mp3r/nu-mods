# AI provider abstraction layer
# This module provides a simple interface to interact with AI providers
# 
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
  let result = try {
    $prompt | agent --model $model | get response
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
  let cleaned = ($result | str trim | split row "</think>" | last | str trim)

  # Check if result is empty
  if $cleaned == "" {
    error make {
      msg: "AI provider returned empty response"
      label: {
        text: "No output received from AI model"
        span: (metadata $model).span
      }
    }
  }

  $cleaned
}
