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
ci github pr check --target main | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 PR but got: ($result | length)"
    assert ($result.0.number == 42) $"Expected PR #42"
    assert ($result.0.title == "Test PR") $"Expected title 'Test PR'"
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
ci github pr check --target main | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 0) $"Expected empty list but got: ($result)"
  }
}

# Test 3: Get PR info by current branch
export def "test ci github pr info current branch" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "feature/test" exit_code: 0} | to json)
    "MOCK_gh_pr_list_--head_feature_test_--json_number,title,state,mergedAt,mergeable,url,headRefName,baseRefName": ({output: '[{"number":100,"title":"Test Feature","state":"OPEN","mergedAt":null,"mergeable":"MERGEABLE","url":"https://github.com/user/repo/pull/100","headRefName":"feature/test","baseRefName":"main"}]' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github pr info | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success"
    assert ($result.number == 100) $"Expected PR number 100"
    assert ($result.state == "OPEN") $"Expected state OPEN"
    assert ($result.merged == false) $"Expected merged false"
    assert ($result.mergeable == "MERGEABLE") $"Expected mergeable"
  }
}

# Test 4: Get PR info by PR number
export def "test ci github pr info by number" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_pr_view_42_--json_number,title,state,mergedAt,mergeable,url,headRefName,baseRefName": ({output: '{"number":42,"title":"Fix Bug","state":"MERGED","mergedAt":"2024-01-01T10:00:00Z","mergeable":"UNKNOWN","url":"https://github.com/user/repo/pull/42","headRefName":"fix/bug","baseRefName":"main"}' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
42 | ci github pr info | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success"
    assert ($result.number == 42) $"Expected PR number 42"
    assert ($result.state == "MERGED") $"Expected state MERGED"
    assert ($result.merged == true) $"Expected merged true"
  }
}

# Test 5: Get PR info by branch name
export def "test ci github pr info by branch" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_pr_list_--head_feature_new_--json_number,title,state,mergedAt,mergeable,url,headRefName,baseRefName": ({output: '[{"number":99,"title":"New Feature","state":"OPEN","mergedAt":null,"mergeable":"CONFLICTING","url":"https://github.com/user/repo/pull/99","headRefName":"feature/new","baseRefName":"develop"}]' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
'feature/new' | ci github pr info | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success"
    assert ($result.number == 99) $"Expected PR number 99"
    assert ($result.mergeable == "CONFLICTING") $"Expected CONFLICTING"
    assert ($result.base_branch == "develop") $"Expected base develop"
  }
}

# Test 6: Get PR info - not found
export def "test ci github pr info not found" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_pr_list_--head_nonexistent_--json_number,title,state,mergedAt,mergeable,url,headRefName,baseRefName": ({output: '[]' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
'nonexistent' | ci github pr info | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "not_found") $"Expected not_found status"
    assert ($result.error != null) $"Expected error message"
  }
}

# Test 7: Create new PR
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

# Test 6: Merge PR with squash (default)
export def "test ci github pr merge squash default" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_pr_merge_123_--squash": ({output: "Merged PR #123" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github pr merge 123 | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success but got: ($result.status)"
    assert ($result.pr_number == 123) $"Expected PR 123"
  }
}

# Test 7: Merge PR with merge method
export def "test ci github pr merge with method" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_pr_merge_456_--merge": ({output: "Merged PR #456" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github pr merge 456 --method merge | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success"
  }
}

# Test 8: Merge PR with auto-merge enabled
export def "test ci github pr merge auto" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_pr_merge_789_--squash_--auto": ({output: "Merged PR #789" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github pr merge 789 --auto | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success"
  }
}

# Test 9: Merge PR failure
export def "test ci github pr merge failure" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_pr_merge_999_--squash": ({output: "Error: PR has conflicts" exit_code: 1} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github pr merge 999 | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "failed") $"Expected failed status"
    assert ($result.error != null) $"Expected error message"
  }
}

# Test 10: List PRs with state filter
export def "test ci github pr list with filter" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_gh_pr_list_--state_open_--json_number,title,author_--limit_30": ({output: '[{"number":1,"title":"First PR","author":{"login":"user1"}},{"number":2,"title":"Second PR","author":{"login":"user2"}}]' exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/github.nu *
ci github pr list --state open | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 PRs but got: ($result | length)"
    assert ($result.0.number == 1) $"Expected PR #1"
    assert ($result.0.title == "First PR") $"Expected 'First PR'"
    assert ($result.1.number == 2) $"Expected PR #2"
    assert ($result.1.title == "Second PR") $"Expected 'Second PR'"
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
ci github workflow list | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 runs but got: ($result | length)"
    assert ($result.0.databaseId == 123) $"Expected run ID 123"
    assert ($result.0.name == "CI") $"Expected workflow name 'CI'"
    assert ($result.0.conclusion == "success") $"Expected conclusion 'success'"
    assert ($result.1.databaseId == 124) $"Expected run ID 124"
    assert ($result.1.status == "in_progress") $"Expected status 'in_progress'"
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
ci github workflow list --status failure | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 1) $"Expected 1 run but got: ($result | length)"
    assert ($result.0.databaseId == 125) $"Expected run ID 125"
    assert ($result.0.conclusion == "failure") $"Expected conclusion 'failure'"
    assert ($result.0.name == "Build") $"Expected workflow name 'Build'"
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
ci github workflow view 123 | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success status"
    assert ($result.run_id == 123) $"Expected run ID 123"
    assert ($result.name == "CI") $"Expected workflow name 'CI'"
    assert ($result.branch == "main") $"Expected branch 'main'"
    assert ($result.conclusion == "success") $"Expected conclusion 'success'"
    assert (($result.jobs | length) == 1) $"Expected 1 job"
    assert ($result.jobs.0.name == "build") $"Expected job name 'build'"
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
ci github workflow cancel 124 | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success status"
    assert ($result.run_id == 124) $"Expected run_id 124"
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
ci github workflow rerun 125 | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success status"
    assert ($result.run_id == 125) $"Expected run_id 125"
  }
}
