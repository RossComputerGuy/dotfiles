{
  description = "A Flake of my NixOS machines";

  inputs.expidus-sdk = {
    url = github:ExpidusOS/sdk;
    inputs = {
      nixpkgs.follows = "nixpkgs";
      home-manager.follows = "home-manager";
    };
  };

  inputs.nur.url = github:nix-community/NUR;
  inputs.nixos-unstable.url = github:NixOS/nixpkgs/nixos-unstable;

  inputs.nixpkgs = {
    url = github:NixOS/nixpkgs/nixos-23.05;
    flake = false;
  };

  inputs.home-manager = {
    url = github:nix-community/home-manager/release-23.05;
    flake = false;
  };

  inputs.darwin = {
    url = github:lnl7/nix-darwin/master;
    inputs.nixpkgs.follows = "expidus-sdk";
  };

  nixConfig = rec {
    trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
    substituters = [ "https://cache.nixos.org" "https://cache.garnix.io" ];
    trusted-substituters = substituters;
    fallback = true;
  };

  outputs = { self, expidus-sdk, nur, nixos-unstable, home-manager, nixpkgs, darwin }@inputs:
    with expidus-sdk.lib;
    let
      overlays = {
        nur = nur.overlay;
        default = (final: prev: {
          path = expidus.channels.nixpkgs;

          rtl8723bs-firmware = prev.runCommand "rtl8723bs-firmware" {} ''
            mkdir -p $out
          '';
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

      machines = [ "lavienrose" "zeta-gundam" ];
      forAllMachines = genAttrs machines;

      users = [ "ross" ];
      forAllUsers = genAttrs users;

      darwinMachines = [ "Hizack" ];
      forAllDarwinMachines = genAttrs darwinMachines;
    in {
      inherit overlays;
      legacyPackages = nixpkgsFor;

      packages = builtins.mapAttrs (system: pkgs: {
        homeConfigurations = forAllUsers (user:
          expidus-sdk.lib.homeManagerConfiguration {
            inherit pkgs;
            inherit (expidus-sdk) lib;
            modules = [
              ./users/${user}/home.nix
              ./users/${user}/home-${pkgs.targetPlatform.parsed.kernel.name}.nix
            ];
          });
        } // (optionalAttrs pkgs.targetPlatform.isDarwin {
          darwinConfigurations = forAllDarwinMachines (machine:
            darwin.lib.darwinSystem {
              inherit system;
              inputs = {
                inherit darwin;
                nixpkgs = expidus-sdk;
              };
              modules = [
                ./system/default.nix
                ./system/darwin.nix
                ./devices/${machine}/default.nix
              ];
            });
        })) nixpkgsFor;

      nixosConfigurations = forAllMachines (machine:
        import "${expidus.channels.nixpkgs}/nixos/lib/eval-config.nix" (rec {
          system = "x86_64-linux";
          inherit (expidus-sdk) lib;
          pkgs = nixpkgsFor.${system};
          modules = let
            nur-modules = import nur.outPath {
              pkgs = nixpkgsFor.${system};
              nurpkgs = nixpkgsFor.${system};
            };
          in [
            {
              documentation.nixos.enable = false;
            }
            "${expidus.channels.home-manager}/nixos"
            ./system/default.nix
            ./system/linux/default.nix
            ./devices/${machine}/default.nix
            nur-modules.repos.ilya-fedin.modules.flatpak-fonts
            nur-modules.repos.ilya-fedin.modules.flatpak-icons
          ];
        }));
    };
}
