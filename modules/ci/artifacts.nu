use ../common/help show-help
use log.nu *

# Artifacts operations - show help
export def "ci artifacts" [] {
  show-help "ci artifacts"
}

# Generate per-arch platform data files from downloaded artifacts
export def "ci artifacts platform-data" [
  version: string
  artifacts_path: string
  project_name: string
  --archive-ext: string = ".tgz"
  --hash-suffix: string = "-nix.sha256"
]: [
  nothing -> list<string>
] {
  $"Generating platform data for version ($version)" | ci log info

  # Create data directory
  mkdir data

  let archive_files = (glob $"($artifacts_path)/**/*($archive_ext)")
  let repo = ($env.GITHUB_REPOSITORY? | default "")

  mut created = []

  for file in $archive_files {
    let filename = ($file | path basename)
    let platform = ($filename | str replace $"($project_name)-($version)-" "" | str replace $archive_ext "")

    # Find corresponding hash file
    let hash_file = ($file | str replace $archive_ext $hash_suffix)
    let hash = try {
      open $hash_file | str trim
    } catch {|err|
      $"Hash file not found for ($filename)" | ci log error
      continue
    }

    let url = $"https://github.com/($repo)/releases/download/v($version)/($filename)"

    let platform_data = {url: $url hash: $hash}
    $platform_data | to json | save --force $"data/($platform).json"
    $"Generated data/($platform).json" | ci log info
    $created = ($created | append $"data/($platform).json")
  }

  $created
}

# Checkout release branch and generate platform data
export def "ci artifacts platform-data-for" [
  version: string
  project_name: string
  artifacts_path: string = "./artifacts"
]: [
  nothing -> list<string>
] {
  let branch_name = $"release/($version)"
  $"Checking out release branch: ($branch_name)" | ci log info

  try {
    git checkout $branch_name
  } catch {|err|
    $"Failed to checkout branch: ($err.msg)" | ci log error
    return []
  }

  ci artifacts platform-data $version $artifacts_path $project_name

  glob "data/*.json"
}
