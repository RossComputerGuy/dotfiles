{
  description = "A Flake of my NixOS machines";

  inputs.expidus-sdk.url = github:ExpidusOS/sdk;
  inputs.nur.url = github:nix-community/NUR;
  inputs.utils.url = "github:numtide/flake-utils";

  inputs.darwin = {
    url = github:lnl7/nix-darwin/master;
    inputs.nixpkgs.follows = "expidus-sdk";
  };

  outputs = { self, expidus-sdk, nur, utils, darwin }:
    with expidus-sdk.lib;
    let
      home-manager = import "${expidus.channels.home-manager}/flake.nix" {
        self = home-manager;
        nixpkgs = expidus-sdk;
        inherit utils;
      };

      overlays = {
        nur = nur.overlay;
        default = (final: prev: {
          alacritty = prev.alacritty.overrideAttrs (prev:
            let commit = "2291610f72d5fabbdd60ca080cc305301f0306f9";
            in rec {
              version = "0.11.1-${commit}";

              src = final.fetchFromGitHub {
                owner = "alacritty";
                repo = "alacritty";
                rev = commit;
                sha256 = "sha256-XQxoJvR21ZzspQd66UFLPKl789l+RPYz9AxuHjHGZKs=";
              };

              cargoSha256 = "0000000000000000000000000000000000000000000000000000";

              cargoDeps = prev.cargoDeps.overrideAttrs (final.lib.const {
                name = "alacritty-${version}-vendor";
                inherit src;
                outputHash = cargoSha256;
              });
           });
        });
      };

      nixpkgsFor = genAttrs [ "x86_64-darwin" "x86_64-linux" ] (system:
        import expidus-sdk.outPath {
          inherit system;
          overlays = (builtins.attrValues overlays);
          config = {
            allowUnfree = true;
          };
        });

      # TODO: add "zeta-gundam" once "networking.hostId" and extra filesystems are added in
      machines = [ "lavienrose" ];
      forAllMachines = genAttrs machines;

      users = [ "ross" ];
      forAllUsers = genAttrs users;

      darwinMachines = [ "tross-mac" ];
      forAllDarwinMachines = genAttrs darwinMachines;
    in {
      inherit overlays;
      legacyPackages = nixpkgsFor;

      darwinConfigurations = forAllDarwinMachines (machine:
        darwin.lib.darwinSystem {
          system = "x86_64-darwin";
          inputs = {
            inherit darwin;
            nixpkgs = expidus-sdk;
          };
          modules = [
            ./system/base.nix
            ./system/darwin.nix
            ./devices/${machine}/default.nix
          ];
        });

      homeConfigurations = forAllUsers (user:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgsFor.${expidus.system.current};
          inherit (expidus-sdk) lib;
          username = user;
          system = expidus.system.current;
          modules = [
            ./users/${user}/home.nix
          ];
        });

      nixosConfigurations = forAllMachines (machine:
        import "${expidus-sdk.outPath}/nixos/lib/eval-config.nix" (rec {
          system = "x86_64-linux";
          inherit (expidus-sdk) lib;
          pkgs = nixpkgsFor.${system};
          modules = let
            nur-modules = import nur.outPath {
              pkgs = nixpkgsFor.${system};
              nurpkgs = nixpkgsFor.${system};
            };
          in [
            ./system/base.nix
            ./system/linux/default.nix
            ./devices/${machine}/default.nix
            nur-modules.repos.ilya-fedin.modules.flatpak-fonts
            nur-modules.repos.ilya-fedin.modules.flatpak-icons
          ];
        }));
    };
}
