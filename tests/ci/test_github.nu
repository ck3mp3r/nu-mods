# Test ci/github.nu with mocked gh commands
# Focus: Test PR and workflow operations

use std/assert
use ../../modules/nu-mimic *
use test_wrappers.nu * # Import wrapped commands FIRST
use ../../modules/ci/github.nu * # Then import module under test

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
export def --env "test ci github pr check finds existing pr" [] {
  mimic reset

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "feature/test-branch"
  }

  mimic register gh {
    args: ['pr' 'list' '--head' 'feature/test-branch' '--base' 'main' '--json' 'number,title,url']
    returns: '[{"number":42,"title":"Test PR","url":"https://github.com/user/repo/pull/42"}]'
  }

  let result = (ci github pr check --target main)

  assert (($result | length) == 1) $"Expected 1 PR but got: ($result | length)"
  assert ($result.0.number == 42) $"Expected PR #42"
  assert ($result.0.title == "Test PR") $"Expected title 'Test PR'"

  mimic verify
}

# Test 2: Check for existing PR - not found
export def --env "test ci github pr check no existing pr" [] {
  mimic reset

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "feature/new-branch"
  }

  mimic register gh {
    args: ['pr' 'list' '--head' 'feature/new-branch' '--base' 'main' '--json' 'number,title,url']
    returns: '[]'
  }

  let result = (ci github pr check --target main)

  assert (($result | length) == 0) $"Expected empty list but got: ($result)"

  mimic verify
}

# Test 3: Get PR info by current branch
export def --env "test ci github pr info current branch" [] {
  mimic reset

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "feature/test"
  }

  mimic register gh {
    args: ['pr' 'list' '--head' 'feature/test' '--json' 'number,title,state,mergedAt,mergeable,url,headRefName,baseRefName']
    returns: '[{"number":100,"title":"Test Feature","state":"OPEN","mergedAt":null,"mergeable":"MERGEABLE","url":"https://github.com/user/repo/pull/100","headRefName":"feature/test","baseRefName":"main"}]'
  }

  let result = (ci github pr info)

  assert ($result.status == "success") $"Expected success"
  assert ($result.number == 100) $"Expected PR number 100"
  assert ($result.state == "OPEN") $"Expected state OPEN"
  assert ($result.merged == false) $"Expected merged false"
  assert ($result.mergeable == "MERGEABLE") $"Expected mergeable"

  mimic verify
}

# Test 4: Get PR info by PR number
export def --env "test ci github pr info by number" [] {
  mimic reset

  mimic register gh {
    args: ['pr' 'view' 42 '--json' 'number,title,state,mergedAt,mergeable,url,headRefName,baseRefName']
    returns: '{"number":42,"title":"Fix Bug","state":"MERGED","mergedAt":"2024-01-01T10:00:00Z","mergeable":"UNKNOWN","url":"https://github.com/user/repo/pull/42","headRefName":"fix/bug","baseRefName":"main"}'
  }

  let result = (42 | ci github pr info)

  assert ($result.status == "success") $"Expected success"
  assert ($result.number == 42) $"Expected PR number 42"
  assert ($result.state == "MERGED") $"Expected state MERGED"
  assert ($result.merged == true) $"Expected merged true"

  mimic verify
}

# Test 5: Get PR info by branch name
export def --env "test ci github pr info by branch" [] {
  mimic reset

  mimic register gh {
    args: ['pr' 'list' '--head' 'feature/new' '--json' 'number,title,state,mergedAt,mergeable,url,headRefName,baseRefName']
    returns: '[{"number":99,"title":"New Feature","state":"OPEN","mergedAt":null,"mergeable":"CONFLICTING","url":"https://github.com/user/repo/pull/99","headRefName":"feature/new","baseRefName":"develop"}]'
  }

  let result = ('feature/new' | ci github pr info)

  assert ($result.status == "success") $"Expected success"
  assert ($result.number == 99) $"Expected PR number 99"
  assert ($result.mergeable == "CONFLICTING") $"Expected CONFLICTING"
  assert ($result.base_branch == "develop") $"Expected base develop"

  mimic verify
}

# Test 6: Get PR info - not found
export def --env "test ci github pr info not found" [] {
  mimic reset

  mimic register gh {
    args: ['pr' 'list' '--head' 'nonexistent' '--json' 'number,title,state,mergedAt,mergeable,url,headRefName,baseRefName']
    returns: '[]'
  }

  let result = ('nonexistent' | ci github pr info)

  assert ($result.status == "not_found") $"Expected not_found status"
  assert ($result.error != null) $"Expected error message"

  mimic verify
}

# Test 7: Create new PR
export def --env "test ci github pr create new" [] {
  mimic reset

  mimic register gh {
    args: ['pr' 'create' '--title' 'feat: add feature' '--body' 'Description here' '--base' 'main']
    returns: "https://github.com/user/repo/pull/43"
  }

  let result = (ci github pr create 'feat: add feature' 'Description here' --target main)

  assert ($result.status == "success") $"Expected success status but got: ($result.status)"
  assert ($result.number == 43) $"Expected PR #43 but got: ($result.number)"

  mimic verify
}

# Test 4: Create draft PR
export def --env "test ci github pr create draft" [] {
  mimic reset

  mimic register gh {
    args: ['pr' 'create' '--title' 'wip: feature' '--body' 'Draft description' '--base' 'develop' '--draft']
    returns: "https://github.com/user/repo/pull/44"
  }

  let result = (ci github pr create 'wip: feature' 'Draft description' --target develop --draft)

  assert ($result.status == "success") $"Expected success status but got: ($result.status)"
  assert ($result.number == 44) $"Expected PR #44 but got: ($result.number)"

  mimic verify
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
export def --env "test ci github pr merge squash default" [] {
  mimic reset

  mimic register gh {
    args: ['pr' 'merge' 123 '--squash']
    returns: "Merged PR #123"
  }

  let result = (ci github pr merge 123)

  assert ($result.status == "success") $"Expected success but got: ($result.status)"
  assert ($result.pr_number == 123) $"Expected PR 123"

  mimic verify
}

# Test 7: Merge PR with merge method
export def --env "test ci github pr merge with method" [] {
  mimic reset

  mimic register gh {
    args: ['pr' 'merge' 456 '--merge']
    returns: "Merged PR #456"
  }

  let result = (ci github pr merge 456 --method merge)

  assert ($result.status == "success") $"Expected success"

  mimic verify
}

# Test 8: Merge PR with auto-merge enabled
export def --env "test ci github pr merge auto" [] {
  mimic reset

  mimic register gh {
    args: ['pr' 'merge' 789 '--squash' '--auto']
    returns: "Merged PR #789"
  }

  let result = (ci github pr merge 789 --auto)

  assert ($result.status == "success") $"Expected success"

  mimic verify
}

# Test 9: Merge PR failure
export def --env "test ci github pr merge failure" [] {
  mimic reset

  mimic register gh {
    args: ['pr' 'merge' 999 '--squash']
    returns: "Error: PR has conflicts"
    exit_code: 1
  }

  let result = (ci github pr merge 999)

  assert ($result.status == "failed") $"Expected failed status"
  assert ($result.error != null) $"Expected error message"

  mimic verify
}

# Test 10: List PRs with state filter
export def --env "test ci github pr list with filter" [] {
  mimic reset

  mimic register gh {
    args: ['pr' 'list' '--state' 'open' '--json' 'number,title,author' '--limit' 30]
    returns: '[{"number":1,"title":"First PR","author":{"login":"user1"}},{"number":2,"title":"Second PR","author":{"login":"user2"}}]'
  }

  let result = (ci github pr list --state open)

  assert (($result | length) == 2) $"Expected 2 PRs but got: ($result | length)"
  assert ($result.0.number == 1) $"Expected PR #1"
  assert ($result.0.title == "First PR") $"Expected 'First PR'"
  assert ($result.1.number == 2) $"Expected PR #2"
  assert ($result.1.title == "Second PR") $"Expected 'Second PR'"

  mimic verify
}

# ============================================================================
# WORKFLOW TESTS
# ============================================================================

# Test 7: List workflow runs
export def --env "test ci github workflow list" [] {
  mimic reset

  mimic register gh {
    args: ['run' 'list' '--json' 'databaseId,status,conclusion,name,headBranch' '--limit' 20]
    returns: '[{"databaseId":123,"status":"completed","conclusion":"success","name":"CI","headBranch":"main"},{"databaseId":124,"status":"in_progress","conclusion":null,"name":"Tests","headBranch":"feature"}]'
  }

  let result = (ci github workflow list)

  assert (($result | length) == 2) $"Expected 2 runs but got: ($result | length)"
  assert ($result.0.databaseId == 123) $"Expected run ID 123"
  assert ($result.0.name == "CI") $"Expected workflow name 'CI'"
  assert ($result.0.conclusion == "success") $"Expected conclusion 'success'"
  assert ($result.1.databaseId == 124) $"Expected run ID 124"
  assert ($result.1.status == "in_progress") $"Expected status 'in_progress'"

  mimic verify
}

# Test 8: Filter workflows by status
export def --env "test ci github workflow list filter by status" [] {
  mimic reset

  mimic register gh {
    args: ['run' 'list' '--status' 'failure' '--json' 'databaseId,status,conclusion,name,headBranch' '--limit' 20]
    returns: '[{"databaseId":125,"status":"completed","conclusion":"failure","name":"Build","headBranch":"develop"}]'
  }

  let result = (ci github workflow list --status failure)

  assert (($result | length) == 1) $"Expected 1 run but got: ($result | length)"
  assert ($result.0.databaseId == 125) $"Expected run ID 125"
  assert ($result.0.conclusion == "failure") $"Expected conclusion 'failure'"
  assert ($result.0.name == "Build") $"Expected workflow name 'Build'"

  mimic verify
}

# Test 9: View specific workflow run
export def --env "test ci github workflow view" [] {
  mimic reset

  mimic register gh {
    args: ['run' 'view' 123 '--json' 'databaseId,status,conclusion,name,headBranch,createdAt,jobs']
    returns: '{"databaseId":123,"status":"completed","conclusion":"success","name":"CI","headBranch":"main","createdAt":"2024-01-01T10:00:00Z","jobs":[{"name":"build","status":"completed","conclusion":"success"}]}'
  }

  let result = (ci github workflow view 123)

  assert ($result.status == "success") $"Expected success status"
  assert ($result.run_id == 123) $"Expected run ID 123"
  assert ($result.name == "CI") $"Expected workflow name 'CI'"
  assert ($result.branch == "main") $"Expected branch 'main'"
  assert ($result.conclusion == "success") $"Expected conclusion 'success'"
  assert (($result.jobs | length) == 1) $"Expected 1 job"
  assert ($result.jobs.0.name == "build") $"Expected job name 'build'"

  mimic verify
}

# Test 10: Get workflow logs
export def --env "test ci github workflow logs" [] {
  mimic reset

  mimic register gh {
    args: ['run' 'view' 123 '--log']
    returns: "Build log output\nTest results\nSuccess!"
  }

  ci github workflow logs 123

  # Just verify the correct command was called
  mimic verify
}

# Test 11: Cancel workflow run
export def --env "test ci github workflow cancel" [] {
  mimic reset

  mimic register gh {
    args: ['run' 'cancel' 124]
    returns: ""
  }

  let result = (ci github workflow cancel 124)

  assert ($result.status == "success") $"Expected success status"
  assert ($result.run_id == 124) $"Expected run_id 124"

  mimic verify
}

# Test 12: Rerun workflow
export def --env "test ci github workflow rerun" [] {
  mimic reset

  mimic register gh {
    args: ['run' 'rerun' 125]
    returns: ""
  }

  let result = (ci github workflow rerun 125)

  assert ($result.status == "success") $"Expected success status"
  assert ($result.run_id == 125) $"Expected run_id 125"

  mimic verify
}
