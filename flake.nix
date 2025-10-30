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
        packages = let
          # Helper function to create individual module packages with dependencies
          mkNuModule = {
            pname,
            src,
            description,
            dependencies ? [],
          }:
            pkgs.stdenvNoCC.mkDerivation {
              inherit pname src;
              version = "0.1.0";

              dontBuild = true;
              dontConfigure = true;

              installPhase = ''
                runHook preInstall

                mkdir -p $out/share/nushell/modules/${pname}
                cp -r * $out/share/nushell/modules/${pname}/

                # Copy dependencies at the same level (as sibling modules)
                ${pkgs.lib.concatMapStringsSep "\n" (dep: ''
                  if [ -d "${dep}/share/nushell/modules" ]; then
                    cp -r "${dep}"/share/nushell/modules/* $out/share/nushell/modules/
                  fi
                '') dependencies}

                runHook postInstall
              '';

              meta = with pkgs.lib; {
                inherit description;
                license = licenses.mit;
                platforms = platforms.all;
              };
            };
        in {
          # Standard library modules (no dependencies)
          std = mkNuModule {
            pname = "std";
            src = ./modules/std;
            description = "Standard library utilities for Nushell modules";
          };

          # Individual module packages (with dependencies)
          ai = mkNuModule {
            pname = "ai";
            src = ./modules/ai;
            description = "AI-powered git operations for Nushell";
            dependencies = [self.packages.${system}.std];
          };

          # Global package that bundles all modules
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "nu-mods";
            version = "0.1.0";
            src = ./.;

            buildInputs = [
              self.packages.${system}.std
              self.packages.${system}.ai
            ];

            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/nushell/modules

              # Copy individual modules from their packages
              # Note: Dependencies are already included in each package
              ${pkgs.lib.concatMapStringsSep "\n" (pkg: ''
                  if [ -d "${pkg}/share/nushell/modules" ]; then
                    cp -r "${pkg}"/share/nushell/modules/* $out/share/nushell/modules/
                  fi
                '') [
                  self.packages.${system}.std
                  self.packages.${system}.ai
                ]}

              # Copy any additional files (README, etc.)
              cp README.md $out/share/nushell/ 2>/dev/null || true

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
          nu-mods-std = self.packages.${prev.system}.std;
          nu-mods-ai = self.packages.${prev.system}.ai;
        };
      };
    };
}
