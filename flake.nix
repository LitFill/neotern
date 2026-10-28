{
  description = "neotern — Neovim drawn as a native Tern surface";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      manifest = (lib.importTOML ./Cargo.toml).package;

      mkNeotern =
        pkgs:
        pkgs.rustPlatform.buildRustPackage {
          pname = manifest.name;
          inherit (manifest) version;

          src = lib.cleanSource ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
            # tern-sdk is a git dependency; fetch it at the rev pinned in Cargo.lock
            allowBuiltinFetchGit = true;
          };

          nativeBuildInputs = [ pkgs.makeWrapper ];

          # neotern spawns `nvim --embed`; fall back to nixpkgs' nvim only if
          # the user has none on PATH (--suffix, so their own nvim wins).
          postInstall = ''
            wrapProgram $out/bin/neotern \
              --suffix PATH : ${lib.makeBinPath [ pkgs.neovim ]}
          '';

          meta = {
            inherit (manifest) description;
            mainProgram = "neotern";
            platforms = systems;
          };
        };
    in
    {
      packages = forAllSystems (pkgs: rec {
        neotern = mkNeotern pkgs;
        default = neotern;
      });

      apps = forAllSystems (pkgs: rec {
        neotern = {
          type = "app";
          program = lib.getExe self.packages.${pkgs.system}.neotern;
        };
        default = neotern;
      });

      overlays.default = final: _prev: {
        neotern = mkNeotern final;
      };

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ self.packages.${pkgs.system}.neotern ];
          packages = with pkgs; [
            rust-analyzer
            clippy
            rustfmt
            neovim
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
