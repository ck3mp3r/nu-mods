# Test ci/github.nu with mocked gh commands
# Focus: Test PR and workflow operations

use std/assert
use ../mocks.nu *
use ../../modules/ci/github.nu *

# ============================================================================
# SUMMARY TESTS
# ============================================================================

# Test: GitHub summary with string input
export def "test ci github summary with string" [] {
  let test_file = $"/tmp/nu_test_summary_(random chars).md"

  with-env {
    GITHUB_STEP_SUMMARY: $test_file
  } {
    try {
      let test_script = $"
use modules/ci/github.nu *
'# Test Summary' | ci github summary"
      nu -c $test_script

      # Verify file was created and contains content
      assert ($test_file | path exists) "Summary file should exist"
      let content = (open $test_file)
      assert ($content | str contains "# Test Summary") $"Expected summary content but got: ($content)"
    } catch {|e|
      if ($test_file | path exists) { rm $test_file }
      error make {msg: $e.msg}
    }

    # Clean up
    if ($test_file | path exists) { rm $test_file }
  }
}

# Test: GitHub summary with list input
export def "test ci github summary with list" [] {
  let test_file = $"/tmp/nu_test_summary_list_(random chars).md"

  with-env {
    GITHUB_STEP_SUMMARY: $test_file
  } {
    try {
      let test_script = $"
use modules/ci/github.nu *
['## Results', '- Item 1', '- Item 2'] | ci github summary"
      nu -c $test_script

      # Verify file contains all list items
      let content = (open $test_file)
      assert ($content | str contains "## Results") $"Expected results header but got: ($content)"
      assert ($content | str contains "- Item 1") $"Expected item 1 but got: ($content)"
      assert ($content | str contains "- Item 2") $"Expected item 2 but got: ($content)"
    } catch {|e|
      if ($test_file | path exists) { rm $test_file }
      error make {msg: $e.msg}
    }

    # Clean up
    if ($test_file | path exists) { rm $test_file }
  }
}

# Test: GitHub summary with newline flag
export def "test ci github summary with newline flag" [] {
  let test_file = $"/tmp/nu_test_summary_newline_(random chars).md"

  with-env {
    GITHUB_STEP_SUMMARY: $test_file
  } {
    try {
      let test_script = $"
use modules/ci/github.nu *
['Line 1', 'Line 2'] | ci github summary --newline"
      nu -c $test_script

      # Verify newlines are present
      let content = (open $test_file)
      assert ($content | str contains "Line 1\n") $"Expected newline after Line 1 but got: ($content)"
      assert ($content | str contains "Line 2\n") $"Expected newline after Line 2 but got: ($content)"
    } catch {|e|
      if ($test_file | path exists) { rm $test_file }
      error make {msg: $e.msg}
    }

    # Clean up
    if ($test_file | path exists) { rm $test_file }
  }
}

# Test: GitHub summary without GITHUB_STEP_SUMMARY env var
export def "test ci github summary without env var" [] {
  let test_script = "
use modules/ci/github.nu *
'Test content' | ci github summary
"
  # This should log an error but not crash
  # Capture both stdout and stderr
  let result = (do { nu -c $test_script } | complete)

  # The function should return early - exit code should be 0 (no crash)
  assert ($result.exit_code == 0) $"Expected function to complete without crashing but got exit code: ($result.exit_code)"

  # Check that error message appears in stderr
  let stderr = ($result.stderr | str join "\n")
  let has_error = (($stderr | str contains "GITHUB_STEP_SUMMARY") or ($stderr | str contains "Not in a GitHub Actions environment"))
  assert $has_error $"Expected error about missing env var but got: ($stderr)"
}

# ============================================================================
# PR TESTS
# ============================================================================

# Test 1: Check for existing PR - found
export def "test ci github pr check finds existing pr" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "feature/test-branch" exit_code: 0} | to json)
    "MOCK_gh_pr_list_--head_feature_test-branch_--base_main_--json_number,title,url": ({output: '[{"number":42,"title":"Test PR","url":"https://github.com/user/repo/pull/42"}]' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github pr check --target main
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "PR #42") $"Expected PR number but got: ($output)"
    assert ($output | str contains "Test PR") $"Expected PR title but got: ($output)"
  }
}

# Test 2: Check for existing PR - not found
export def "test ci github pr check no existing pr" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "feature/new-branch" exit_code: 0} | to json)
    "MOCK_gh_pr_list_--head_feature_new-branch_--base_main_--json_number,title,url": ({output: '[]' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github pr check --target main
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "No existing PR") $"Expected no PR message but got: ($output)"
  }
}

# Test 3: Create new PR
export def "test ci github pr create new" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_pr_create_--title_feat:_add_feature_--body_Description_here_--base_main": ({output: "https://github.com/user/repo/pull/43" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github pr create 'feat: add feature' 'Description here' --target main
"
    let output = (nu -c $test_script | str join "\n")

    assert (($output | str contains "#43") or ($output | str contains "pull/43")) $"Expected PR creation success but got: ($output)"
  }
}

# Test 4: Create draft PR
export def "test ci github pr create draft" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_pr_create_--title_wip:_feature_--body_Draft_description_--base_develop_--draft": ({output: "https://github.com/user/repo/pull/44" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github pr create 'wip: feature' 'Draft description' --target develop --draft
"
    let output = (nu -c $test_script | str join "\n")

    assert (($output | str contains "draft") or ($output | str contains "Draft")) $"Expected draft PR but got: ($output)"
  }
}

# Test 5: Update existing PR
# TODO: Fix mock naming for gh api with -f flags
# export def "test ci github pr update" [] {
#   with-env {
#     NU_TEST_MODE: "true"
#     "MOCK_gh_repo_view_--json_owner,name": ({output: '{"owner":{"login":"testuser"},"name":"testrepo"}' exit_code: 0} | to json)
#     "MOCK_gh_api_-X_PATCH__repos_testuser_testrepo_pulls_42_-f_title=Updated_Title_-f_body=Updated_description": ({output: '{"number":42}' exit_code: 0} | to json)
#   } {
#     let test_script = "
# use tests/mocks.nu *
# use modules/ci/github.nu *
# ci github pr update 42 --title 'Updated Title' --body 'Updated description'
# "
#     let output = (nu -c $test_script | str join "\n")
#     
#     assert (($output | str contains "Updated") or ($output | str contains "42")) $"Expected update success but got: ($output)"
#   }
# }

# Test 6: List PRs with state filter
export def "test ci github pr list with filter" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_pr_list_--state_open_--json_number,title,author_--limit_30": ({output: '[{"number":1,"title":"First PR","author":{"login":"user1"}},{"number":2,"title":"Second PR","author":{"login":"user2"}}]' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github pr list --state open
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "First PR") $"Expected first PR but got: ($output)"
    assert ($output | str contains "Second PR") $"Expected second PR but got: ($output)"
  }
}

# ============================================================================
# WORKFLOW TESTS
# ============================================================================

# Test 7: List workflow runs
export def "test ci github workflow list" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_run_list_--json_databaseId,status,conclusion,name,headBranch_--limit_20": ({output: '[{"databaseId":123,"status":"completed","conclusion":"success","name":"CI","headBranch":"main"},{"databaseId":124,"status":"in_progress","conclusion":null,"name":"Tests","headBranch":"feature"}]' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github workflow list
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "123") $"Expected run ID but got: ($output)"
    assert ($output | str contains "CI") $"Expected workflow name but got: ($output)"
  }
}

# Test 8: Filter workflows by status
export def "test ci github workflow list filter by status" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_run_list_--status_failure_--json_databaseId,status,conclusion,name,headBranch_--limit_20": ({output: '[{"databaseId":125,"status":"completed","conclusion":"failure","name":"Build","headBranch":"develop"}]' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github workflow list --status failure
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "125") $"Expected filtered run but got: ($output)"
    assert (($output | str contains "failure") or ($output | str contains "Build")) $"Expected failure status but got: ($output)"
  }
}

# Test 9: View specific workflow run
export def "test ci github workflow view" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_run_view_123_--json_databaseId,status,conclusion,name,headBranch,createdAt,jobs": ({output: '{"databaseId":123,"status":"completed","conclusion":"success","name":"CI","headBranch":"main","createdAt":"2024-01-01T10:00:00Z","jobs":[{"name":"build","status":"completed","conclusion":"success"}]}' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github workflow view 123
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "123") $"Expected run ID but got: ($output)"
    assert ($output | str contains "success") $"Expected success status but got: ($output)"
  }
}

# Test 10: Get workflow logs
export def "test ci github workflow logs" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_run_view_123_--log": ({output: "Build log output\nTest results\nSuccess!" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github workflow logs 123
"
    let output = (nu -c $test_script | str join "\n")

    assert (($output | str contains "Build log") or ($output | str contains "Test results")) $"Expected log output but got: ($output)"
  }
}

# Test 11: Cancel workflow run
export def "test ci github workflow cancel" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_run_cancel_124": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github workflow cancel 124
"
    let output = (nu -c $test_script | str join "\n")

    assert (($output | str contains "cancel") or ($output | str contains "124")) $"Expected cancel confirmation but got: ($output)"
  }
}

# Test 12: Rerun workflow
export def "test ci github workflow rerun" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_run_rerun_125": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github workflow rerun 125
"
    let output = (nu -c $test_script | str join "\n")

    assert (($output | str contains "rerun") or ($output | str contains "125")) $"Expected rerun confirmation but got: ($output)"
  }
}
