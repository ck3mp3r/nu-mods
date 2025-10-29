{
  description = "Collection of Nushell modules for extending shell functionality";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["aarch64-darwin" "aarch64-linux" "x86_64-linux"];
      perSystem = {system, ...}: let
        pkgs = import inputs.nixpkgs {inherit system;};
      in {
        packages = {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "nu-mods";
            version = "0.1.0";
            src = ./.;

            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/nushell/modules
              cp -r * $out/share/nushell/modules/

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Collection of Nushell modules for extending shell functionality";
              license = licenses.mit;
              platforms = platforms.all;
            };
          };
        };

        devShells = {
          default = inputs.devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              ./devenv.nix
            ];
          };
        };

        formatter = pkgs.alejandra;
      };

      flake = {
        overlays.default = final: prev: {
          nu-mods = self.packages.${prev.system}.default;
        };
      };
    };
}
