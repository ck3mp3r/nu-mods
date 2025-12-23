# Test ci/scm.nu with mocked git commands
# Focus: Test branch creation with different flow types and ticket IDs

use std/assert
use ../../modules/nu-mimic *
use test_wrappers.nu * # Import wrapped commands FIRST
use ../../modules/ci/scm.nu * # Then import module under test

# Test 1: Feature branch with ticket ID via --prefix flag
export def --env "test ci scm branch feature with ticket prefix" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "main"
  }

  mimic register git {
    args: ['switch' 'main']
    returns: "Already on 'main'"
  }

  mimic register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mimic register git {
    args: ['rev-parse' '--verify' 'JIRA-1234/feature/add-login']
    returns: ""
    exit_code: 128
  }

  mimic register git {
    args: ['switch' '-c' 'JIRA-1234/feature/add-login']
    returns: "Switched to a new branch 'JIRA-1234/feature/add-login'"
  }

  let result = ('add login' | ci scm branch --feature --prefix 'JIRA-1234')

  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "JIRA-1234/feature/add-login") $"Expected branch name with ticket but got: ($result.branch)"
  assert ($result.rebased == false) $"Expected rebased to be false"

  mimic verify
}

# Test 2: Release branch with ticket ID
export def --env "test ci scm branch release with ticket" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "develop"
  }

  mimic register git {
    args: ['switch' 'main']
    returns: "Switched to branch 'main'"
  }

  mimic register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mimic register git {
    args: ['rev-parse' '--verify' 'PROJ-500/release/v2.1.0']
    returns: ""
    exit_code: 128
  }

  mimic register git {
    args: ['switch' '-c' 'PROJ-500/release/v2.1.0']
    returns: "Switched to a new branch 'PROJ-500/release/v2.1.0'"
  }

  let result = ('v2.1.0' | ci scm branch --release --prefix 'PROJ-500')

  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "PROJ-500/release/v2.1.0") $"Expected release branch but got: ($result.branch)"

  mimic verify
}

# Test 3: Hotfix branch from custom base
export def --env "test ci scm branch hotfix with custom base" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "develop"
  }

  mimic register git {
    args: ['switch' 'production']
    returns: "Switched to branch 'production'"
  }

  mimic register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mimic register git {
    args: ['rev-parse' '--verify' 'SEC-999/hotfix/patch-vulnerability']
    returns: ""
    exit_code: 128
  }

  mimic register git {
    args: ['switch' '-c' 'SEC-999/hotfix/patch-vulnerability']
    returns: "Switched to a new branch 'SEC-999/hotfix/patch-vulnerability'"
  }

  let result = ('patch vulnerability' | ci scm branch --hotfix --from production --prefix 'SEC-999')

  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "SEC-999/hotfix/patch-vulnerability") $"Expected hotfix branch but got: ($result.branch)"
  assert ($result.rebased == false) $"Expected rebased to be false"

  mimic verify
}

# Test 4: Fix branch without ticket ID
export def --env "test ci scm branch fix without ticket" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "main"
  }

  mimic register git {
    args: ['switch' 'main']
    returns: "Already on 'main'"
  }

  mimic register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mimic register git {
    args: ['rev-parse' '--verify' 'fix/login-bug']
    returns: ""
    exit_code: 128
  }

  mimic register git {
    args: ['switch' '-c' 'fix/login-bug']
    returns: "Switched to a new branch 'fix/login-bug'"
  }

  let result = ('login bug' | ci scm branch --fix)

  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "fix/login-bug") $"Expected fix branch without ticket but got: ($result.branch)"

  mimic verify
}

# Test 5: Chore branch with description sanitization
export def --env "test ci scm branch sanitizes description" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "main"
  }

  mimic register git {
    args: ['switch' 'main']
    returns: "Already on 'main'"
  }

  mimic register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mimic register git {
    args: ['rev-parse' '--verify' 'MAINT-100/chore/update-dependencies-and-cleanup']
    returns: ""
    exit_code: 128
  }

  mimic register git {
    args: ['switch' '-c' 'MAINT-100/chore/update-dependencies-and-cleanup']
    returns: "Switched to a new branch"
  }

  let result = ('Update Dependencies AND Cleanup!!!' | ci scm branch --chore --prefix 'MAINT-100')

  # Should lowercase, replace spaces, remove special chars
  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "MAINT-100/chore/update-dependencies-and-cleanup") $"Expected sanitized branch but got: ($result.branch)"

  mimic verify
}

# Test 7: Error handling - not a git repo
export def --env "test ci scm branch error not git repo" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: "fatal: not a git repository"
    exit_code: 128
  }

  let result = ('test' | ci scm branch --feature)

  assert ($result.status == "error") $"Expected error status"
  assert ($result.branch == null) $"Expected null branch"
  assert ($result.error != null) $"Expected error message"

  mimic verify
}

# Test 8: Default to feature when no flow flag provided
export def --env "test ci scm branch defaults to feature" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "main"
  }

  mimic register git {
    args: ['switch' 'main']
    returns: "Already on 'main'"
  }

  mimic register git {
    args: ['pull']
    returns: "Already up to date."
  }

  mimic register git {
    args: ['rev-parse' '--verify' 'feature/default-test']
    returns: ""
    exit_code: 128
  }

  mimic register git {
    args: ['switch' '-c' 'feature/default-test']
    returns: "Switched to a new branch 'feature/default-test'"
  }

  let result = ('default test' | ci scm branch)

  assert ($result.status == "success") $"Expected success status"
  assert ($result.branch == "feature/default-test") $"Expected feature branch by default but got: ($result.branch)"

  mimic verify
}

# ============================================================================
# COMMIT TESTS
# ============================================================================

# Test 9: Commit specific files with message
export def --env "test ci scm commit with files and message" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['add' 'file1.txt' 'file2.txt']
    returns: ""
  }

  mimic register git {
    args: ['commit' '-m' 'feat: add new feature']
    returns: "[main abc123] feat: add new feature"
  }

  let result = (['file1.txt' 'file2.txt'] | ci scm commit --message 'feat: add new feature')

  assert ($result.status == "success") $"Expected success but got: ($result.status)"
  assert ($result.message == "feat: add new feature") $"Expected message but got: ($result.message)"

  mimic verify
}

# Test 10: Commit with custom message  
export def --env "test ci scm commit with custom message" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['add' '-A']
    returns: ""
  }

  mimic register git {
    args: ['commit' '-m' 'test message']
    returns: "[main def456] test message"
  }

  let result = (ci scm commit -m 'test message')

  assert ($result.status == "success") $"Expected success but got: ($result.status)"
  assert ($result.message == "test message") $"Expected test message"

  mimic verify
}

# Test 11: Commit single file via string input
export def --env "test ci scm commit single file" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['add' 'flake.lock']
    returns: ""
  }

  mimic register git {
    args: ['commit' '-m' 'chore: update flake.lock']
    returns: "[main ghi789] chore: update flake.lock"
  }

  let result = ('flake.lock' | ci scm commit -m 'chore: update flake.lock')

  assert ($result.status == "success") $"Expected success but got: ($result.status)"

  mimic verify
}

# Test 12: Commit with no changes
export def --env "test ci scm commit no changes" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['add' '-A']
    returns: ""
  }

  mimic register git {
    args: ['diff' '--cached' '--name-only']
    returns: ""
  }

  let result = (ci scm commit)

  assert ($result.status == "success") $"Expected success status"
  assert ($result.message == "No changes to commit") $"Expected no changes message"

  mimic verify
}

# Test 13: Commit failure handling
export def --env "test ci scm commit failure" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['add' 'file.txt']
    returns: "fatal: pathspec 'file.txt' did not match any files"
    exit_code: 128
  }

  let result = ('file.txt' | ci scm commit -m 'test')

  assert ($result.status == "failed") $"Expected failed status"
  assert ($result.error != null) $"Expected error message"
  assert ($result.pushed == false) $"Expected pushed to be false"

  mimic verify
}

# Test 14: Commit with push flag
export def --env "test ci scm commit with push" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['add' '-A']
    returns: ""
  }

  mimic register git {
    args: ['commit' '-m' 'feat: add feature']
    returns: "[main abc123] feat: add feature"
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "feature/test-branch"
  }

  mimic register git {
    args: ['push' 'origin' 'feature/test-branch']
    returns: "To github.com:user/repo.git"
  }

  let result = (ci scm commit -m 'feat: add feature' --push)

  assert ($result.status == "success") $"Expected success status"
  assert ($result.pushed == true) $"Expected pushed to be true"
  assert ($result.message == "feat: add feature") $"Expected commit message"

  mimic verify
}

# Test 15: Commit with push failure
export def --env "test ci scm commit push failure" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['add' '-A']
    returns: ""
  }

  mimic register git {
    args: ['commit' '-m' 'test']
    returns: "[main def456] test"
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "main"
  }

  mimic register git {
    args: ['push' 'origin' 'main']
    returns: "fatal: remote error"
    exit_code: 1
  }

  let result = (ci scm commit -m 'test' --push)

  assert ($result.status == "success") $"Expected success status for commit"
  assert ($result.pushed == false) $"Expected pushed to be false"
  assert ($result.error != null) $"Expected push error message"

  mimic verify
}

# ============================================================================
# CHANGES TESTS
# ============================================================================

# Test 16: Get all changes since branch created
export def --env "test ci scm changes all files" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['merge-base' 'HEAD' 'main']
    returns: "abc123def456"
  }

  mimic register git {
    args: ['diff' '--name-only' 'abc123def456']
    returns: "file1.txt\nfile2.nu\nsrc/main.nu"
  }

  let result = (ci scm changes)

  assert (($result | length) == 3) $"Expected 3 files"
  assert ($result | any {|f| $f == "file1.txt" }) $"Expected file1.txt"
  assert ($result | any {|f| $f == "file2.nu" }) $"Expected file2.nu"
  assert ($result | any {|f| $f == "src/main.nu" }) $"Expected src/main.nu"

  mimic verify
}

# Test 17: Get changes with custom base branch
export def --env "test ci scm changes custom base" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['merge-base' 'HEAD' 'develop']
    returns: "xyz789abc"
  }

  mimic register git {
    args: ['diff' '--name-only' 'xyz789abc']
    returns: "README.md\ndocs/guide.md"
  }

  let result = (ci scm changes --base develop)

  assert (($result | length) == 2) $"Expected 2 files"
  assert ($result | any {|f| $f == "README.md" }) $"Expected README.md"
  assert ($result | any {|f| $f == "docs/guide.md" }) $"Expected docs/guide.md"

  mimic verify
}

# Test 18: Get only staged files
export def --env "test ci scm changes staged only" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['diff' '--cached' '--name-only']
    returns: "staged1.nu\nstaged2.txt"
  }

  let result = (ci scm changes --staged)

  assert (($result | length) == 2) $"Expected 2 staged files"
  assert ($result | any {|f| $f == "staged1.nu" }) $"Expected staged1.nu"
  assert ($result | any {|f| $f == "staged2.txt" }) $"Expected staged2.txt"

  mimic verify
}

# Test 19: No changes returns empty list
export def --env "test ci scm changes no changes" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['merge-base' 'HEAD' 'main']
    returns: "abc123"
  }

  mimic register git {
    args: ['diff' '--name-only' 'abc123']
    returns: ""
  }

  let result = (ci scm changes)

  assert (($result | length) == 0) $"Expected empty list"

  mimic verify
}

# ============================================================================
# CONFIG TESTS
# ============================================================================

# Test 20: Config with email auto-derives name
export def --env "test ci scm config auto derive name" [] {
  mimic reset

  mimic register git {
    args: ['config' '--local' 'user.name' 'john doe']
    returns: ""
  }

  mimic register git {
    args: ['config' '--local' 'user.email' 'john.doe@example.com']
    returns: ""
  }

  let result = ('john.doe@example.com' | ci scm config)

  assert ($result.status == "success") $"Expected success but got: ($result.status)"
  assert ($result.name == "john doe") $"Expected 'john doe' but got: ($result.name)"
  assert ($result.email == "john.doe@example.com") $"Expected email"
  assert ($result.scope == "local") $"Expected local scope"

  mimic verify
}

# Test 21: Config with custom name
export def --env "test ci scm config custom name" [] {
  mimic reset

  mimic register git {
    args: ['config' '--local' 'user.name' 'John Doe']
    returns: ""
  }

  mimic register git {
    args: ['config' '--local' 'user.email' 'john@example.com']
    returns: ""
  }

  let result = ('john@example.com' | ci scm config --name 'John Doe')

  assert ($result.status == "success") $"Expected success"
  assert ($result.name == "John Doe") $"Expected 'John Doe'"
  assert ($result.email == "john@example.com") $"Expected email"

  mimic verify
}

# Test 22: Config with global flag
export def --env "test ci scm config global" [] {
  mimic reset

  mimic register git {
    args: ['config' '--global' 'user.name' 'bot user']
    returns: ""
  }

  mimic register git {
    args: ['config' '--global' 'user.email' 'bot_user@ci.example.com']
    returns: ""
  }

  let result = ('bot_user@ci.example.com' | ci scm config --global)

  assert ($result.status == "success") $"Expected success"
  assert ($result.name == "bot user") $"Expected bot user with underscores replaced"
  assert ($result.scope == "global") $"Expected global scope"

  mimic verify
}

# Test 23: Config with invalid email
export def --env "test ci scm config invalid email" [] {
  mimic reset

  let result = ('notanemail' | ci scm config)

  assert ($result.status == "error") $"Expected error status"
  assert ($result.error == "Invalid email format") $"Expected invalid email error"

  mimic verify
}

# Test 24: Config with hyphenated email username
export def --env "test ci scm config hyphenated email" [] {
  mimic reset

  mimic register git {
    args: ['config' '--local' 'user.name' 'first middle last']
    returns: ""
  }

  mimic register git {
    args: ['config' '--local' 'user.email' 'first-middle-last@company.com']
    returns: ""
  }

  let result = ('first-middle-last@company.com' | ci scm config)

  assert ($result.status == "success") $"Expected success"
  assert ($result.name == "first middle last") $"Expected hyphens replaced with spaces"

  mimic verify
}
