use ../common/help show-help
use log.nu *

# Homebrew operations - show help
export def "ci homebrew" [] {
  show-help "ci homebrew"
}

# Update version and per-arch sha256 hashes in a formula
export def "ci homebrew update-formula" [
  version: string
  binary_name: string
  architectures: list<record>
]: [
  string -> string
] {
  let formula = $in
    | str replace -r 'version "[^"]*"' $'version "($version)"'
    | str replace -r 'v[0-9]+\.[0-9]+\.[0-9]+' $'v($version)' --all

  $architectures | reduce --fold $formula {|arch acc|
    $acc
    | str replace -r $'($binary_name)-[0-9]+\.[0-9]+\.[0-9]+-($arch.name)\.tgz' $'($binary_name)-($version)-($arch.name).tgz'
    | str replace -r $'($arch.name)\.tgz"\s+sha256 "[a-f0-9]{64}"' $"($arch.name).tgz\"\n      sha256 \"($arch.hash)\""
  }
}
