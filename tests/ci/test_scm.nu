# Test ci/scm.nu with mocked git commands
# Focus: Test branch creation with different flow types and ticket IDs

use std/assert
use ../mocks.nu *
use ../../modules/ci/scm.nu *

# Test 1: Feature branch with ticket ID from stdin
export def "test ci scm branch feature with ticket from stdin" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "main" exit_code: 0} | to json)
    "MOCK_git_checkout_main": ({output: "Already on 'main'" exit_code: 0} | to json)
    "MOCK_git_pull": ({output: "Already up to date." exit_code: 0} | to json)
    "MOCK_git_checkout_-b_JIRA-1234_feature_add-login": ({output: "Switched to a new branch 'JIRA-1234/feature/add-login'" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'JIRA-1234' | ci scm branch 'add login' --feature
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "JIRA-1234/feature/add-login") $"Expected branch name with ticket but got: ($output)"
    assert ($output | str contains "Successfully created") $"Expected success message but got: ($output)"
  }
}

# Test 2: Release branch with ticket ID
export def "test ci scm branch release with ticket" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "develop" exit_code: 0} | to json)
    "MOCK_git_checkout_main": ({output: "Switched to branch 'main'" exit_code: 0} | to json)
    "MOCK_git_pull": ({output: "Already up to date." exit_code: 0} | to json)
    "MOCK_git_checkout_-b_PROJ-500_release_v2.1.0": ({output: "Switched to a new branch 'PROJ-500/release/v2.1.0'" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'PROJ-500' | ci scm branch 'v2.1.0' --release
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "PROJ-500/release/v2.1.0") $"Expected release branch but got: ($output)"
  }
}

# Test 3: Hotfix branch from custom base
export def "test ci scm branch hotfix with custom base" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "develop" exit_code: 0} | to json)
    "MOCK_git_checkout_production": ({output: "Switched to branch 'production'" exit_code: 0} | to json)
    "MOCK_git_pull": ({output: "Already up to date." exit_code: 0} | to json)
    "MOCK_git_checkout_-b_SEC-999_hotfix_patch-vulnerability": ({output: "Switched to a new branch 'SEC-999/hotfix/patch-vulnerability'" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'SEC-999' | ci scm branch 'patch vulnerability' --hotfix --from production
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "SEC-999/hotfix/patch-vulnerability") $"Expected hotfix branch but got: ($output)"
    assert ($output | str contains "from production") $"Expected base branch mentioned but got: ($output)"
  }
}

# Test 4: Fix branch without ticket ID
export def "test ci scm branch fix without ticket" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "main" exit_code: 0} | to json)
    "MOCK_git_checkout_main": ({output: "Already on 'main'" exit_code: 0} | to json)
    "MOCK_git_pull": ({output: "Already up to date." exit_code: 0} | to json)
    "MOCK_git_checkout_-b_fix_login-bug": ({output: "Switched to a new branch 'fix/login-bug'" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
ci scm branch 'login bug' --fix
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "fix/login-bug") $"Expected fix branch without ticket but got: ($output)"
  }
}

# Test 5: Chore branch with description sanitization
export def "test ci scm branch sanitizes description" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "main" exit_code: 0} | to json)
    "MOCK_git_checkout_main": ({output: "Already on 'main'" exit_code: 0} | to json)
    "MOCK_git_pull": ({output: "Already up to date." exit_code: 0} | to json)
    "MOCK_git_checkout_-b_MAINT-100_chore_update-dependencies-and-cleanup": ({output: "Switched to a new branch" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'MAINT-100' | ci scm branch 'Update Dependencies AND Cleanup!!!' --chore
"
    let output = (nu -c $test_script | str join "\n")

    # Should lowercase, replace spaces, remove special chars
    assert ($output | str contains "update-dependencies-and-cleanup") $"Expected sanitized description but got: ($output)"
  }
}

# Test 6: No-checkout flag
export def "test ci scm branch no checkout flag" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "main" exit_code: 0} | to json)
    "MOCK_git_checkout_main": ({output: "Already on 'main'" exit_code: 0} | to json)
    "MOCK_git_pull": ({output: "Already up to date." exit_code: 0} | to json)
    "MOCK_git_branch_TEST-789_feature_new-thing": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'TEST-789' | ci scm branch 'new thing' --feature --no-checkout
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "Created branch") $"Expected creation message but got: ($output)"
    assert ($output | str contains "TEST-789/feature/new-thing") $"Expected branch name but got: ($output)"
  }
}

# Test 7: Error handling - not a git repo
export def "test ci scm branch error not git repo" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "fatal: not a git repository" exit_code: 128} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
ci scm branch 'test' --feature
"
    let result = (nu -c $test_script | complete)

    assert ($result.exit_code != 0) $"Expected non-zero exit code but got: ($result.exit_code)"
  }
}

# Test 8: Default to feature when no flow flag provided
export def "test ci scm branch defaults to feature" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "main" exit_code: 0} | to json)
    "MOCK_git_checkout_main": ({output: "Already on 'main'" exit_code: 0} | to json)
    "MOCK_git_pull": ({output: "Already up to date." exit_code: 0} | to json)
    "MOCK_git_checkout_-b_feature_default-test": ({output: "Switched to a new branch 'feature/default-test'" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
ci scm branch 'default test'
"
    let output = (nu -c $test_script | str join "\n")

    assert ($output | str contains "feature/default-test") $"Expected feature branch by default but got: ($output)"
  }
}
