{pkgs}: let
  scripts = {
    test = pkgs.writeShellScriptBin "test" ''
      echo 'No tests configured yet. Add test files with #[test] annotations.'
    '';
    check = pkgs.writeShellScriptBin "check" ''
      nu -c 'ls **/*.nu | each { |it| nu --ide-check 100 $it.name }'
    '';
    fmt = pkgs.writeShellScriptBin "fmt" ''
      find . -name '*.nu' -type f -exec topiary format {} \;
    '';
  };
in {
  packages = [
    pkgs.nushell
    pkgs.topiary-nu
    pkgs.gh
    scripts.test
    scripts.check
    scripts.fmt
  ];

  shellHook = ''
    echo
    echo "🐚 Nu-Mods Development Environment"
    echo "Helper scripts you can run:"
    echo ""
    printf '  %-15s  %s\n' 'test' 'Run Nushell module tests (placeholder)'
    printf '  %-15s  %s\n' 'check' 'Check Nushell syntax for all .nu files'
    printf '  %-15s  %s\n' 'fmt' 'Format Nushell code with topiary'
    echo
    echo "To use modules locally, run: install-local"
    echo
  '';
}
