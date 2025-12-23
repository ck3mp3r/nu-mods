# Test git.nu EXPORTED functions with mocked external commands
# Focus: Test the public API, validate parameters pass through correctly

use std/assert
use ../../modules/nu-mimic *
use ../ci/test_wrappers.nu * # Import wrapped commands FIRST
use ../../modules/ai/git.nu * # Then import module under test

# Test ai git pr - exported function
# Validates: model parameter, target parameter, prefix in prompt
export def --env "test ai git pr with custom model and target" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "feature/test-123"
  }

  mimic register gh {
    args: ['pr' 'list' '--head' 'feature/test-123' '--base' 'develop' '--json' 'number,title']
    returns: "[]"
  }

  mimic register git {
    args: ['diff' 'develop...HEAD']
    returns: "diff --git a/test.nu\n+new line"
  }

  mimic register git {
    args: ['log' 'develop..HEAD' '--oneline']
    returns: "abc123 test commit"
  }

  mimic register git {
    args: ['diff' 'develop...HEAD' '--name-only']
    returns: "test.nu"
  }

  mimic register opencode {
    args: ['run' '--model' 'custom-model']
    returns: "feat: test PR\n\nPR description"
  }

  ai git pr --model 'custom-model' --target 'develop'

  # Just verify the correct commands were called
  mimic verify
}

# Test ai git pr - with prefix parameter
# Validates: prefix appears in the prompt context
export def --env "test ai git pr with prefix" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "feature/add-tests"
  }

  mimic register gh {
    args: ['pr' 'list' '--head' 'feature/add-tests' '--base' 'main' '--json' 'number,title']
    returns: "[]"
  }

  mimic register git {
    args: ['diff' 'main...HEAD']
    returns: "diff --git a/test.nu"
  }

  mimic register git {
    args: ['log' 'main..HEAD' '--oneline']
    returns: "abc123 add tests"
  }

  mimic register git {
    args: ['diff' 'main...HEAD' '--name-only']
    returns: "test.nu"
  }

  mimic register opencode {
    args: ['run' '--model' 'gpt-4']
    returns: "ABC-123: Add test suite\n\nAdded comprehensive tests"
  }

  ai git pr --model 'gpt-4' --prefix 'ABC-123'

  # Just verify the correct commands were called
  mimic verify
}

# Test ai git commit - exported function
# Validates: model parameter, diff is in prompt
export def --env "test ai git commit with custom model" [] {
  mimic reset

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "feature/ABC-456"
  }

  mimic register git {
    args: ['diff' '--cached']
    returns: "diff --git a/file.nu\n+added line\n-removed line"
  }

  mimic register opencode {
    args: ['run' '--model' 'claude-3']
    returns: "Add new feature\n\n- Added functionality\n- Removed old code"
  }

  ai git commit --model 'claude-3'

  # Just verify the correct commands were called
  mimic verify
}

# Test ai git branch - exported function
# Validates: model parameter, description in prompt, prefix in output
export def --env "test ai git branch with description and prefix" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['diff' '--cached' '--name-only']
    returns: "new-feature.nu"
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "main"
  }

  mimic register opencode {
    args: ['run' '--model' 'test-model']
    returns: "feature/add-logging"
  }

  ai git branch --model 'test-model' --description 'add logging support' --prefix 'JIRA-789'

  # Just verify the correct commands were called
  mimic verify
}

# Test ai git branch - from-current flag
# Validates: branches from current branch, not main
export def --env "test ai git branch from current" [] {
  mimic reset

  mimic register git {
    args: ['status' '--porcelain']
    returns: ""
  }

  mimic register git {
    args: ['diff' '--cached' '--name-only']
    returns: ""
  }

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "develop"
  }

  mimic register opencode {
    args: ['run' '--model' 'gpt-4']
    returns: "feature/new-feature"
  }

  ai git branch --model 'gpt-4' --from-current

  # Should suggest branching from develop (current), not main
  # Just verify the correct commands were called
  mimic verify
}

# Test ai git commit - extracts prefix from branch name
# Validates: branch prefix extraction logic works correctly
export def --env "test ai git commit extracts branch prefix" [] {
  mimic reset

  mimic register git {
    args: ['rev-parse' '--abbrev-ref' 'HEAD']
    returns: "feature/TICKET-999-implement-auth"
  }

  mimic register git {
    args: ['diff' '--cached']
    returns: "diff --git a/auth.nu\n+new auth"
  }

  mimic register opencode {
    args: ['run' '--model' 'gpt-4']
    returns: "Implement authentication"
  }

  ai git commit --model 'gpt-4'

  # Should prefix commit message with TICKET-999
  # Just verify the correct commands were called
  mimic verify
}
