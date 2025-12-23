# Test ci/scm.nu with mocked git commands
# Focus: Test branch creation with different flow types and ticket IDs

use std/assert
use ../../modules/nu-mock *
use test_wrappers.nu * # Import wrapped commands FIRST
use ../../modules/ci/scm.nu * # Then import module under test

# Test 1: Feature branch with ticket ID via --prefix flag
export def --env "test ci scm branch feature with ticket prefix" [] {
  mock reset

  mock register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mock register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "main"
  }

  mock register git {
    args: ['switch' 'main']
    returns: "Already on 'main'"
  }

  mock register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mock register git {
    args: ['rev-parse' '--verify' 'JIRA-1234/feature/add-login']
    returns: ""
    exit_code: 128
  }

  mock register git {
    args: ['switch' '-c' 'JIRA-1234/feature/add-login']
    returns: "Switched to a new branch 'JIRA-1234/feature/add-login'"
  }

  let result = ('add login' | ci scm branch --feature --prefix 'JIRA-1234')

  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "JIRA-1234/feature/add-login") $"Expected branch name with ticket but got: ($result.branch)"
  assert ($result.rebased == false) $"Expected rebased to be false"

  mock verify
}

# Test 2: Release branch with ticket ID
export def --env "test ci scm branch release with ticket" [] {
  mock reset

  mock register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mock register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "develop"
  }

  mock register git {
    args: ['switch' 'main']
    returns: "Switched to branch 'main'"
  }

  mock register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mock register git {
    args: ['rev-parse' '--verify' 'PROJ-500/release/v2.1.0']
    returns: ""
    exit_code: 128
  }

  mock register git {
    args: ['switch' '-c' 'PROJ-500/release/v2.1.0']
    returns: "Switched to a new branch 'PROJ-500/release/v2.1.0'"
  }

  let result = ('v2.1.0' | ci scm branch --release --prefix 'PROJ-500')

  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "PROJ-500/release/v2.1.0") $"Expected release branch but got: ($result.branch)"

  mock verify
}

# Test 3: Hotfix branch from custom base
export def --env "test ci scm branch hotfix with custom base" [] {
  mock reset

  mock register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mock register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "develop"
  }

  mock register git {
    args: ['switch' 'production']
    returns: "Switched to branch 'production'"
  }

  mock register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mock register git {
    args: ['rev-parse' '--verify' 'SEC-999/hotfix/patch-vulnerability']
    returns: ""
    exit_code: 128
  }

  mock register git {
    args: ['switch' '-c' 'SEC-999/hotfix/patch-vulnerability']
    returns: "Switched to a new branch 'SEC-999/hotfix/patch-vulnerability'"
  }

  let result = ('patch vulnerability' | ci scm branch --hotfix --from production --prefix 'SEC-999')

  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "SEC-999/hotfix/patch-vulnerability") $"Expected hotfix branch but got: ($result.branch)"
  assert ($result.rebased == false) $"Expected rebased to be false"

  mock verify
}

# Test 4: Fix branch without ticket ID
export def --env "test ci scm branch fix without ticket" [] {
  mock reset

  mock register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mock register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "main"
  }

  mock register git {
    args: ['switch' 'main']
    returns: "Already on 'main'"
  }

  mock register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mock register git {
    args: ['rev-parse' '--verify' 'fix/login-bug']
    returns: ""
    exit_code: 128
  }

  mock register git {
    args: ['switch' '-c' 'fix/login-bug']
    returns: "Switched to a new branch 'fix/login-bug'"
  }

  let result = ('login bug' | ci scm branch --fix)

  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "fix/login-bug") $"Expected fix branch without ticket but got: ($result.branch)"

  mock verify
}

# Test 5: Chore branch with description sanitization
export def --env "test ci scm branch sanitizes description" [] {
  mock reset

  mock register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mock register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "main"
  }

  mock register git {
    args: ['switch' 'main']
    returns: "Already on 'main'"
  }

  mock register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mock register git {
    args: ['rev-parse' '--verify' 'MAINT-100/chore/update-dependencies-and-cleanup']
    returns: ""
    exit_code: 128
  }

  mock register git {
    args: ['switch' '-c' 'MAINT-100/chore/update-dependencies-and-cleanup']
    returns: "Switched to a new branch"
  }

  let result = ('Update Dependencies AND Cleanup!!!' | ci scm branch --chore --prefix 'MAINT-100')

  # Should lowercase, replace spaces, remove special chars
  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "MAINT-100/chore/update-dependencies-and-cleanup") $"Expected sanitized branch but got: ($result.branch)"

  mock verify
}

# Test 7: Error handling - not a git repo
export def --env "test ci scm branch error not git repo" [] {
  mock reset

  mock register git {
    args: ['status' '--porcelain']
    returns: "fatal: not a git repository"
    exit_code: 128
  }

  let result = ('test' | ci scm branch --feature)

  assert ($result.status == "error") $"Expected error status"
  assert ($result.branch == null) $"Expected null branch"
  assert ($result.error != null) $"Expected error message"

  mock verify
}

# Test 8: Default to feature when no flow flag provided
export def --env "test ci scm branch defaults to feature" [] {
  mock reset

  mock register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mock register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "main"
  }

  mock register git {
    args: ['switch' 'main']
    returns: "Already on 'main'"
  }

  mock register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mock register git {
    args: ['rev-parse' '--verify' 'feature/default-test']
    returns: ""
    exit_code: 128
  }

  mock register git {
    args: ['switch' '-c' 'feature/default-test']
    returns: "Switched to a new branch 'feature/default-test'"
  }

  let result = ('default test' | ci scm branch)

  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "feature/default-test") $"Expected feature branch by default but got: ($result.branch)"

  mock verify
}

# ============================================================================
# COMMIT TESTS
# ============================================================================

# Test 9: Commit specific files with message
export def --env "test ci scm commit with files and message" [] {
  mock reset

  mock register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mock register git {
    args: ['add' 'file1.txt' 'file2.txt']
    returns: ""
  }

  mock register git {
    args: ['commit' '-m' 'feat: add new feature']
    returns: "[main abc123] feat: add new feature"
  }

  let result = (['file1.txt' 'file2.txt'] | ci scm commit --message 'feat: add new feature')

  assert ($result.status == "success") $"Expected success but got: ($result.status)"
  assert ($result.message == "feat: add new feature") $"Expected message but got: ($result.message)"

  mock verify
}

# Test 10: Commit with custom message  
export def --env "test ci scm commit with custom message" [] {
  mock reset

  mock register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mock register git {
    args: ['add' '-A']
    returns: ""
  }

  mock register git {
    args: ['commit' '-m' 'test message']
    returns: "[main def456] test message"
  }

  let result = (ci scm commit -m 'test message')

  assert ($result.status == "success") $"Expected success but got: ($result.status)"
  assert ($result.message == "test message") $"Expected test message"

  mock verify
}

# Test 11: Commit single file via string input
export def "test ci scm commit single file" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_add_flake.lock": ({output: "" exit_code: 0} | to json)
    "MOCK_git_commit_-m_chore:_update_flake.lock": ({output: "[main ghi789] chore: update flake.lock" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'flake.lock' | ci scm commit -m 'chore: update flake.lock' | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success but got: ($result.status)"
  }
}

# Test 12: Commit with no changes
export def "test ci scm commit no changes" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_add_-A": ({output: "" exit_code: 0} | to json)
    "MOCK_git_diff_--cached_--name-only": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
ci scm commit | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success status"
    assert ($result.message == "No changes to commit") $"Expected no changes message"
  }
}

# Test 13: Commit failure handling
export def "test ci scm commit failure" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_add_file.txt": ({output: "fatal: pathspec 'file.txt' did not match any files" exit_code: 128} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'file.txt' | ci scm commit -m 'test' | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "failed") $"Expected failed status"
    assert ($result.error != null) $"Expected error message"
    assert ($result.pushed == false) $"Expected pushed to be false"
  }
}

# Test 14: Commit with push flag
export def "test ci scm commit with push" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_add_-A": ({output: "" exit_code: 0} | to json)
    "MOCK_git_commit_-m_feat:_add_feature": ({output: "[main abc123] feat: add feature" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "feature/test-branch" exit_code: 0} | to json)
    "MOCK_git_push_origin_feature_test-branch": ({output: "To github.com:user/repo.git" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
ci scm commit -m 'feat: add feature' --push | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success status"
    assert ($result.pushed == true) $"Expected pushed to be true"
    assert ($result.message == "feat: add feature") $"Expected commit message"
  }
}

# Test 15: Commit with push failure
export def "test ci scm commit push failure" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_add_-A": ({output: "" exit_code: 0} | to json)
    "MOCK_git_commit_-m_test": ({output: "[main def456] test" exit_code: 0} | to json)
    "MOCK_git_rev-parse_--abbrev-ref_HEAD": ({output: "main" exit_code: 0} | to json)
    "MOCK_git_push_origin_main": ({output: "fatal: remote error" exit_code: 1} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
ci scm commit -m 'test' --push | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success status for commit"
    assert ($result.pushed == false) $"Expected pushed to be false"
    assert ($result.error != null) $"Expected push error message"
  }
}

# ============================================================================
# CHANGES TESTS
# ============================================================================

# Test 16: Get all changes since branch created
export def "test ci scm changes all files" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_merge-base_HEAD_main": ({output: "abc123def456" exit_code: 0} | to json)
    "MOCK_git_diff_--name-only_abc123def456": ({output: "file1.txt\nfile2.nu\nsrc/main.nu" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
ci scm changes | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 3) $"Expected 3 files"
    assert ($result | any {|f| $f == "file1.txt" }) $"Expected file1.txt"
    assert ($result | any {|f| $f == "file2.nu" }) $"Expected file2.nu"
    assert ($result | any {|f| $f == "src/main.nu" }) $"Expected src/main.nu"
  }
}

# Test 17: Get changes with custom base branch
export def "test ci scm changes custom base" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_merge-base_HEAD_develop": ({output: "xyz789abc" exit_code: 0} | to json)
    "MOCK_git_diff_--name-only_xyz789abc": ({output: "README.md\ndocs/guide.md" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
ci scm changes --base develop | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 files"
    assert ($result | any {|f| $f == "README.md" }) $"Expected README.md"
    assert ($result | any {|f| $f == "docs/guide.md" }) $"Expected docs/guide.md"
  }
}

# Test 18: Get only staged files
export def "test ci scm changes staged only" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_diff_--cached_--name-only": ({output: "staged1.nu\nstaged2.txt" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
ci scm changes --staged | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 2) $"Expected 2 staged files"
    assert ($result | any {|f| $f == "staged1.nu" }) $"Expected staged1.nu"
    assert ($result | any {|f| $f == "staged2.txt" }) $"Expected staged2.txt"
  }
}

# Test 19: No changes returns empty list
export def "test ci scm changes no changes" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_status_--porcelain": ({output: "" exit_code: 0} | to json)
    "MOCK_git_merge-base_HEAD_main": ({output: "abc123" exit_code: 0} | to json)
    "MOCK_git_diff_--name-only_abc123": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
ci scm changes | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert (($result | length) == 0) $"Expected empty list"
  }
}

# ============================================================================
# CONFIG TESTS
# ============================================================================

# Test 20: Config with email auto-derives name
export def "test ci scm config auto derive name" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_config_--local_user.name_john_doe": ({output: "" exit_code: 0} | to json)
    "MOCK_git_config_--local_user.email_john.doe@example.com": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'john.doe@example.com' | ci scm config | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success but got: ($result.status)"
    assert ($result.name == "john doe") $"Expected 'john doe' but got: ($result.name)"
    assert ($result.email == "john.doe@example.com") $"Expected email"
    assert ($result.scope == "local") $"Expected local scope"
  }
}

# Test 21: Config with custom name
export def "test ci scm config custom name" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_config_--local_user.name_John_Doe": ({output: "" exit_code: 0} | to json)
    "MOCK_git_config_--local_user.email_john@example.com": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'john@example.com' | ci scm config --name 'John Doe' | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success"
    assert ($result.name == "John Doe") $"Expected 'John Doe'"
    assert ($result.email == "john@example.com") $"Expected email"
  }
}

# Test 22: Config with global flag
export def "test ci scm config global" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_config_--global_user.name_bot_user": ({output: "" exit_code: 0} | to json)
    "MOCK_git_config_--global_user.email_bot_user@ci.example.com": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'bot_user@ci.example.com' | ci scm config --global | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success"
    assert ($result.name == "bot user") $"Expected bot user with underscores replaced"
    assert ($result.scope == "global") $"Expected global scope"
  }
}

# Test 23: Config with invalid email
export def "test ci scm config invalid email" [] {
  with-env {
    NU_TEST_MODE: "true"
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'notanemail' | ci scm config | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "error") $"Expected error status"
    assert ($result.error == "Invalid email format") $"Expected invalid email error"
  }
}

# Test 24: Config with hyphenated email username
export def "test ci scm config hyphenated email" [] {
  with-env {
    NU_TEST_MODE: "true"
    "MOCK_git_config_--local_user.name_first_middle_last": ({output: "" exit_code: 0} | to json)
    "MOCK_git_config_--local_user.email_first-middle-last@company.com": ({output: "" exit_code: 0} | to json)
  } {
    let test_script = "
use tests/mocks.nu *
use modules/ci/scm.nu *
'first-middle-last@company.com' | ci scm config | to json
"
    let output = (nu -c $test_script)
    let result = ($output | from json)

    assert ($result.status == "success") $"Expected success"
    assert ($result.name == "first middle last") $"Expected hyphens replaced with spaces"
  }
}
