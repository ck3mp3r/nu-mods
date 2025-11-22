{
  pkgs,
  lib,
  config,
  ...
}: {
  packages = [
    pkgs.nushell
    pkgs.gh
    pkgs.topiary
    pkgs.topiary-nu
  ];

  env = {
    TOPIARY_CONFIG_FILE = "${pkgs.topiary-nu}/languages.ncl";
    TOPIARY_LANGUAGE_DIR = "${pkgs.topiary-nu}/languages";
  };

  scripts = {
    test = {
      exec = "echo 'No tests configured yet. Add test files with #[test] annotations.'";
      description = "Run Nushell module tests (placeholder)";
    };
    check = {
      exec = "nu -c 'ls **/*.nu | each { |it| nu --ide-check 100 $it.name }'";
      description = "Check Nushell syntax for all .nu files";
    };
    fmt = {
      exec = "find . -name '*.nu' -type f -exec topiary format --language nu --configuration ${pkgs.topiary-nu} {} \\;";
      description = "Format Nushell code with topiary";
    };
  };

  git-hooks.hooks = {
    # Format Nushell files before commit
    nu-format = {
      enable = true;
      name = "Format Nushell files";
      entry = "${pkgs.topiary}/bin/topiary format --configuration ${pkgs.topiary-nu}";
      language = "system";
      files = "\\.nu$";
      pass_filenames = true;
    };
    # Check syntax before commit
    nu-syntax-check = {
      enable = true;
      name = "Check Nushell syntax";
      entry = "nu -c 'ls **/*.nu | each { |it| nu --ide-check 100 $it.name }'";
      language = "system";
      files = "\\.nu$";
      pass_filenames = false;
    };
  };

  enterShell = let
    scriptLines =
      lib.mapAttrsToList (
        name: script: "printf '  %-15s  %s\\n' '${name}' '${script.description}'"
      )
      config.scripts;
  in ''
    echo
    echo "🐚 Nu-Mods Development Environment"
    echo "Helper scripts you can run:"
    echo ""
    ${lib.concatStringsSep "\n" scriptLines}
    echo
    echo "To use modules locally, run: install-local"
    echo
  '';
}
