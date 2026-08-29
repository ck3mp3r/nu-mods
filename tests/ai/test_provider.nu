use std/assert
use ../../modules/nu-mimic *
use ../ci/test_wrappers.nu *
use ../../modules/ai/provider.nu

export def --env "test provider run with valid response" [] {
  mimic reset
  mimic register agent {
    args: {type: "contains", value: "test prompt"}
    returns: {response: "AI response"}
    exit_code: 0
  }
  let result = (provider execute "test prompt" "test-model")
  assert equal $result "AI response"
  mimic verify
}

export def --env "test provider run strips thinking tags" [] {
  mimic reset
  mimic register agent {
    args: {type: "contains", value: "analyze this code and provide recommendations"}
    returns: {response: "<thinking>reasoning</thinking>final answer"}
    exit_code: 0
  }
  let result = (provider execute "analyze this code and provide recommendations" "gpt-4")
  assert equal $result "final answer"
  mimic verify
}

export def --env "test provider run handles empty response" [] {
  mimic reset
  mimic register agent {
    args: {type: "contains", value: "generate a commit message for this change"}
    returns: {response: ""}
    exit_code: 0
  }
  let result = try {
    provider execute "generate a commit message for this change" "gpt-4"
  } catch {|e|
    $e.msg
  }
  assert str contains $result "empty response"
  mimic verify
}

export def --env "test provider run passes tools to agent" [] {
  mimic reset
  mimic register agent {
    args: {type: "contains", value: "--tools"}
    returns: {response: "tooled response"}
    exit_code: 0
  }
  let result = (provider execute "test prompt" "test-model" --tools {read: {}})
  assert equal $result "tooled response"
  mimic verify
}

export def --env "test provider run passes permissions to agent" [] {
  mimic reset
  mimic register agent {
    args: {type: "contains", value: "--permissions"}
    returns: {response: "permitted response"}
    exit_code: 0
  }
  let result = (provider execute "test prompt" "test-model" --permissions {bash: {allow: ["ls"]}})
  assert equal $result "permitted response"
  mimic verify
}
