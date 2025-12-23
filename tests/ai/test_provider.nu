# Test provider.nu with mocked opencode

use std/assert
use ../../modules/nu-mock *
use ../ci/test_wrappers.nu *
use ../../modules/ai/provider.nu *

# Test provider run with valid response
export def --env "test provider run with valid response" [] {
  mock reset

  mock register opencode {
    args: ['run' '--model' 'test-model' 'test prompt']
    returns: "AI response"
    exit_code: 0
  }

  let result = (run "test prompt" "test-model")
  assert equal $result "AI response"

  mock verify
}

# Test provider run strips thinking tags
export def --env "test provider run strips thinking tags" [] {
  mock reset

  mock register opencode {
    args: ['run' '--model' 'gpt-4' 'analyze this code and provide recommendations']
    returns: "<think>reasoning</think>final answer"
    exit_code: 0
  }

  let result = (run "analyze this code and provide recommendations" "gpt-4")
  assert equal $result "final answer"

  mock verify
}

# Test provider run handles empty response
export def --env "test provider run handles empty response" [] {
  mock reset

  mock register opencode {
    args: ['run' '--model' 'gpt-4' 'generate a commit message for this change']
    returns: ""
    exit_code: 0
  }

  let result = try {
    run "generate a commit message for this change" "gpt-4"
  } catch {|e|
    $e.msg
  }
  assert str contains $result "empty response"

  mock verify
}
