# Test provider.nu with mocked opencode

use std/assert
use mocks.nu *
use ../modules/ai/provider.nu *

# Test provider run with valid response
export def "test provider run with valid response" [] {
  with-env {
    NU_TEST_MODE: "true"
    MOCK_opencode_run_--model_test-model: ({output: "AI response" exit_code: 0} | to json)
  } {
    let result = (run "test prompt" "test-model")
    assert equal $result "AI response"
  }
}

# Test provider run strips thinking tags
export def "test provider run strips thinking tags" [] {
  with-env {
    NU_TEST_MODE: "true"
    MOCK_opencode_run_--model_gpt-4: ({output: "<think>reasoning</think>final answer" exit_code: 0} | to json)
  } {
    let result = (run "analyze this code and provide recommendations" "gpt-4")
    assert equal $result "final answer"
  }
}

# Test provider run handles empty response
export def "test provider run handles empty response" [] {
  with-env {
    NU_TEST_MODE: "true"
    MOCK_opencode_run_--model_gpt-4: ({output: "" exit_code: 0} | to json)
  } {
    let result = try {
      run "generate a commit message for this change" "gpt-4"
    } catch {|e|
      $e.msg
    }
    assert str contains $result "empty response"
  }
}
