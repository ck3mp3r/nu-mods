# Test provider.nu with mocked agent

use std/assert
use ../../modules/nu-mimic *
use ../ci/test_wrappers.nu *
use ../../modules/ai/provider.nu *

# Test provider run with valid response
export def --env "test provider run with valid response" [] {
  mimic reset

  mimic register agent {
    args: ['test prompt' '--model' 'test-model']
    returns: {response: "AI response"}
    exit_code: 0
  }

  let result = (run "test prompt" "test-model")
  assert equal $result "AI response"

  mimic verify
}

# Test provider run strips thinking tags
export def --env "test provider run strips thinking tags" [] {
  mimic reset

  mimic register agent {
    args: ['analyze this code and provide recommendations' '--model' 'gpt-4']
    returns: {response: "<think>reasoning</think>final answer"}
    exit_code: 0
  }

  let result = (run "analyze this code and provide recommendations" "gpt-4")
  assert equal $result "final answer"

  mimic verify
}

# Test provider run handles empty response
export def --env "test provider run handles empty response" [] {
  mimic reset

  mimic register agent {
    args: ['generate a commit message for this change' '--model' 'gpt-4']
    returns: {response: ""}
    exit_code: 0
  }

  let result = try {
    run "generate a commit message for this change" "gpt-4"
  } catch {|e|
    $e.msg
  }
  assert str contains $result "empty response"

  mimic verify
}
