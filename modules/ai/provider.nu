# AI provider abstraction layer
# This module provides a simple interface to interact with AI providers
# 
# NOTE: OpenCode has a bug where using --session with non-existent sessions causes hanging.
# Additionally, using OpenCode without --session creates a new session for every call,
# polluting the session list. There's currently no stateless mode in OpenCode.
#
# TODO: Consider switching to a different provider (e.g., direct API calls to Anthropic/OpenAI)
# or wait for OpenCode to add a stateless mode.

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
  # WARNING: This creates a new session for every call, polluting the session list.
  # This is a known issue with OpenCode - see comments above.
  let result = try {
    opencode run --model $model $prompt
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
