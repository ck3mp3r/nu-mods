{
  description = "Collection of Nushell modules for extending shell functionality";

  inputs = {
    base-nixpkgs.url = "github:ck3mp3r/flakes?dir=base-nixpkgs";
    nixpkgs.follows = "base-nixpkgs/unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    topiary-nu = {
      url = "github:ck3mp3r/flakes?dir=topiary-nu";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Nushell 0.109.1 binaries from GitHub releases (avoids 0.110.0 stdlib bugs)
    nushell-aarch64-darwin = {
      url = "https://github.com/nushell/nushell/releases/download/0.109.1/nu-0.109.1-aarch64-apple-darwin.tar.gz";
      flake = false;
    };
    nushell-aarch64-linux = {
      url = "https://github.com/nushell/nushell/releases/download/0.109.1/nu-0.109.1-aarch64-unknown-linux-gnu.tar.gz";
      flake = false;
    };
    nushell-x86_64-linux = {
      url = "https://github.com/nushell/nushell/releases/download/0.109.1/nu-0.109.1-x86_64-unknown-linux-gnu.tar.gz";
      flake = false;
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
        # Nushell 0.109.1 from GitHub releases (avoids 0.110.0 stdlib bugs)
        nushell = pkgs.stdenvNoCC.mkDerivation {
          pname = "nu";
          version = "0.109.1";

          src =
            if system == "aarch64-darwin"
            then inputs.nushell-aarch64-darwin
            else if system == "aarch64-linux"
            then inputs.nushell-aarch64-linux
            else if system == "x86_64-linux"
            then inputs.nushell-x86_64-linux
            else throw "Unsupported system: ${system}";

          installPhase = ''
            install -D -m755 nu $out/bin/nu
          '';
        };

        overlays = [
          inputs.topiary-nu.overlays.default
          (
            final: next: {inherit nushell;}
          )
        ];
        pkgs = import inputs.nixpkgs {inherit system overlays;};
      in {
        packages = let
          # Helper function to create individual module packages with dependencies
          mkNuModule = {
            pname,
            src,
            description,
            dependencies ? [],
            runtimeInputs ? [],
          }:
            pkgs.stdenvNoCC.mkDerivation {
              inherit pname src;
              version = "0.1.0";

              propagatedBuildInputs = runtimeInputs;

              dontBuild = true;
              dontConfigure = true;

              installPhase = ''
                runHook preInstall

                mkdir -p $out/share/nushell/modules/${pname}
                cp -r * $out/share/nushell/modules/${pname}/

                # Copy dependencies at the same level (as sibling modules)
                ${pkgs.lib.concatMapStringsSep "\n" (dep: ''
                    if [ -d "${dep}/share/nushell/modules" ]; then
                      cp -rn "${dep}"/share/nushell/modules/* $out/share/nushell/modules/
                    fi
                  '')
                  dependencies}

                runHook postInstall
              '';

              meta = with pkgs.lib; {
                inherit description;
                license = licenses.mit;
                platforms = platforms.all;
              };
            };
        in {
          inherit nushell;
          # Common library modules (no dependencies)
          common = mkNuModule {
            pname = "common";
            src = ./modules/common;
            description = "Common library utilities for Nushell modules";
          };

          # Individual module packages (with dependencies)
          ai = mkNuModule {
            pname = "ai";
            src = ./modules/ai;
            description = "AI-powered git operations for Nushell";
            dependencies = [self.packages.${system}.common];
          };

          ci = let
            ciModule = mkNuModule {
              pname = "ci";
              src = ./modules/ci;
              description = "CI/CD SCM flow utilities for Nushell";
              dependencies = [self.packages.${system}.common];
              runtimeInputs = [pkgs.cachix];
            };
          in
            pkgs.symlinkJoin {
              name = "ci";
              paths = [
                ciModule
                pkgs.cachix
              ];
            };

          nu-mimic = mkNuModule {
            pname = "nu-mimic";
            src = ./modules/nu-mimic;
            description = "Mocking framework for Nushell testing";
          };

          # Global package that bundles all modules
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "nu-mods";
            version = "0.1.0";
            src = ./.;

            buildInputs = [
              self.packages.${system}.common
              self.packages.${system}.ai
              self.packages.${system}.ci
              self.packages.${system}.nu-mimic
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
                    cp -rn "${pkg}"/share/nushell/modules/* $out/share/nushell/modules/
                  fi
                '') [
                  self.packages.${system}.common
                  self.packages.${system}.ai
                  self.packages.${system}.ci
                  self.packages.${system}.nu-mimic
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
          default = let
            shellConfig = import ./devshell.nix {inherit pkgs;};
          in
            pkgs.mkShellNoCC {
              inherit (shellConfig) packages shellHook;
            };

          # Minimal CI shell with just essentials for running tests
          # mkShellNoCC avoids pulling in compiler toolchain dependencies
          ci = pkgs.mkShellNoCC {
            packages = [
              pkgs.cachix
              self.packages.${system}.nushell # Use pinned nushell to avoid 0.110.0 bugs
            ];
          };
        };

        formatter = pkgs.alejandra;
      };

      flake = {
        overlays.default = final: prev: {
          nu-mods = self.packages.${prev.system}.default;
          nu-mods-common = self.packages.${prev.system}.common;
          nu-mods-ai = self.packages.${prev.system}.ai;
          nu-mods-ci = self.packages.${prev.system}.ci;
          nu-mods-nu-mimic = self.packages.${prev.system}.nu-mimic;
        };
      };
    };
}
