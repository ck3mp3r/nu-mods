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
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["aarch64-darwin" "aarch64-linux" "x86_64-linux"];
      perSystem = {system, ...}: let
        overlays = [
          inputs.topiary-nu.overlays.default
          (final: previous: {
            nushell = previous.nushell.overrideAttrs (oldAttrs: {
              checkPhase = let
                skippedTests =
                  [
                    "repl::test_config_path::test_default_config_path"
                    "repl::test_config_path::test_xdg_config_bad"
                    "repl::test_config_path::test_xdg_config_empty"
                    # Add the failing SHLVL tests
                    "shell::environment::env::env_shlvl_in_repl"
                    "shell::environment::env::env_shlvl_in_exec_repl"
                  ]
                  ++ previous.lib.optionals previous.stdenv.hostPlatform.isDarwin [
                    "plugins::config::some"
                    "plugins::stress_internals::test_exit_early_local_socket"
                    "plugins::stress_internals::test_failing_local_socket_fallback"
                    "plugins::stress_internals::test_local_socket"
                    "shell::environment::env::path_is_a_list_in_repl"
                  ];
                skippedTestsStr = previous.lib.concatStringsSep " " (previous.lib.map (testId: "--skip=\${testId}") skippedTests);
              in ''
                runHook preCheck

                cargo test -j $NIX_BUILD_CORES --offline -- \
                  --test-threads=$NIX_BUILD_CORES ${skippedTestsStr}

                runHook postCheck
              '';
            });
          })
        ];
        pkgs = import inputs.nixpkgs {inherit system overlays;};
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
        packages = {
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
              pkgs.nushell
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
