# Test wrappers for CI tests
# These wrap external commands to use the nu-mimic framework
# Import this BEFORE importing the module under test

use ../../modules/nu-mimic *

# Wrapped nix command - just calls mock, errors bubble up via try/catch
export def --env --wrapped nix [...args] {
  mimic call 'nix' $args
}

# Wrapped cachix command - just calls mock, errors bubble up via try/catch
export def --env --wrapped cachix [...args] {
  mimic call 'cachix' $args
}

# Wrapped git command
export def --env --wrapped git [...args] {
  mimic call 'git' $args
}

# Wrapped gh command
export def --env --wrapped gh [...args] {
  mimic call 'gh' $args
}

# Wrapped agent command - captures piped input via $in
export def --env --wrapped agent [...args] {
  let input = $in
  mimic call 'agent' ($args | prepend $input)
}
