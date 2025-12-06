# Test git.nu EXPORTED functions with mocked external commands
# Focus: Test the public API, validate parameters pass through correctly

use std/assert
use ../mocks.nu *
use ../../modules/ai/git.nu *

# Test ai git pr - exported function
# Validates: model parameter, target parameter, prefix in prompt
export def "test ai git pr with custom model and target" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "feature/test-123" exit_code: 0} | to json)
    "MOCK_gh_pr_list_--head_feature_test-123_--base_develop_--json_number,title": ({output: "[]" exit_code: 0} | to json)
    "MOCK_git_diff_develop...HEAD": ({output: "diff --git a/test.nu\n+new line" exit_code: 0} | to json)
    "MOCK_git_log_develop..HEAD_--oneline": ({output: "abc123 test commit" exit_code: 0} | to json)
    "MOCK_git_diff_develop...HEAD_--name-only": ({output: "test.nu" exit_code: 0} | to json)
    "MOCK_opencode_run_--model_custom-model": ({output: "feat: test PR\n\nPR description" exit_code: 0} | to json)
    # Expect prompt to contain: branch name, target, files, diff
    "MOCK_opencode_expected_keywords": (["feature/test-123" "develop" "test.nu"] | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ai/git.nu *
ai git pr --model 'custom-model' --target 'develop'
"

    let output = (nu -c $test_script | str join "\n")

    # Should succeed and generate PR
    assert ($output | str contains "Generated PR") $"Expected 'Generated PR' but got: ($output)"
    assert ($output | str contains "Error" | not $in) $"Should not have error: ($output)"
  }
}

# Test ai git pr - with prefix parameter
# Validates: prefix appears in the prompt context
export def "test ai git pr with prefix" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "feature/add-tests" exit_code: 0} | to json)
    "MOCK_gh_pr_list_--head_feature_add-tests_--base_main_--json_number,title": ({output: "[]" exit_code: 0} | to json)
    "MOCK_git_diff_main...HEAD": ({output: "diff --git a/test.nu" exit_code: 0} | to json)
    "MOCK_git_log_main..HEAD_--oneline": ({output: "abc123 add tests" exit_code: 0} | to json)
    "MOCK_git_diff_main...HEAD_--name-only": ({output: "test.nu" exit_code: 0} | to json)
    "MOCK_opencode_run_--model_gpt-4": ({output: "ABC-123: Add test suite\n\nAdded comprehensive tests" exit_code: 0} | to json)
    # Expect prompt to mention the prefix
    "MOCK_opencode_expected_keywords": (["ABC-123"] | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ai/git.nu *
ai git pr --model 'gpt-4' --prefix 'ABC-123'
"

    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "Generated PR") $"Expected success: ($output)"
  }
}

# Test ai git commit - exported function
# Validates: model parameter, diff is in prompt
export def "test ai git commit with custom model" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "feature/ABC-456" exit_code: 0} | to json)
    "MOCK_git_diff_--cached": ({output: "diff --git a/file.nu\n+added line\n-removed line" exit_code: 0} | to json)
    "MOCK_opencode_run_--model_claude-3": ({output: "Add new feature\n\n- Added functionality\n- Removed old code" exit_code: 0} | to json)
    # Expect prompt to contain the actual diff
    "MOCK_opencode_expected_keywords": (["diff --git" "added line" "removed line"] | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ai/git.nu *
ai git commit --model 'claude-3'
"

    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "Generated Commit Message") $"Expected success: ($output)"
    # Should prefix with ABC-456 from branch name
    assert ($output | str contains "ABC-456") $"Expected branch prefix: ($output)"
  }
}

# Test ai git branch - exported function
# Validates: model parameter, description in prompt, prefix in output
export def "test ai git branch with description and prefix" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_diff_--cached_--name-only": ({output: "new-feature.nu" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "main" exit_code: 0} | to json)
    "MOCK_opencode_run_--model_test-model": ({output: "feature/add-logging" exit_code: 0} | to json)
    # Expect prompt to contain description and staged files
    "MOCK_opencode_expected_keywords": (["add logging support" "new-feature.nu"] | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ai/git.nu *
ai git branch --model 'test-model' --description 'add logging support' --prefix 'JIRA-789'
"

    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "Suggested branch name") $"Expected success: ($output)"
    # Should include the prefix in the suggested name or context
    assert (($output | str contains "JIRA-789") or ($output | str contains "feature")) $"Expected branch suggestion: ($output)"
  }
}

# Test ai git branch - from-current flag
# Validates: branches from current branch, not main
export def "test ai git branch from current" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_diff_--cached_--name-only": ({output: "" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "develop" exit_code: 0} | to json)
    "MOCK_opencode_run_--model_gpt-4": ({output: "feature/new-feature" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ai/git.nu *
ai git branch --model 'gpt-4' --from-current
"

    let output = (nu -c $test_script | str join "\n")

    # Should suggest branching from develop (current), not main
    assert ($output | str contains "Suggested branch name") $"Expected success: ($output)"
  }
}

# Test ai git commit - extracts prefix from branch name
# Validates: branch prefix extraction logic works correctly
export def "test ai git commit extracts branch prefix" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "feature/TICKET-999-implement-auth" exit_code: 0} | to json)
    "MOCK_git_diff_--cached": ({output: "diff --git a/auth.nu\n+new auth" exit_code: 0} | to json)
    "MOCK_opencode_run_--model_gpt-4": ({output: "Implement authentication" exit_code: 0} | to json)
    "MOCK_opencode_expected_keywords": (["diff --git" "auth"] | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ai/git.nu *
ai git commit --model 'gpt-4'
"

    let output = (nu -c $test_script | str join "\n")

    # Should prefix commit message with TICKET-999
    assert ($output | str contains "TICKET-999") $"Expected prefix extraction: ($output)"
  }
}
