{
  description = "A Flake of my NixOS machines";

  inputs.expidus-sdk.url = github:ExpidusOS/sdk;
  inputs.nur.url = github:nix-community/NUR;

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

  outputs = { self, expidus-sdk, nur, darwin }:
    with expidus-sdk.lib;
    let
      overlays = {
        nur = nur.overlay;
        default = (final: prev: {
          alacritty = prev.alacritty.overrideAttrs (prev:
            let commit = "79860622a7beb8bbff0602e56977be6018f3aa39";
            in rec {
              version = "0.11.1-${commit}";

              src = final.fetchFromGitHub {
                owner = "alacritty";
                repo = "alacritty";
                rev = commit;
                sha256 = "sha256-BdSlAsOZZ+A4IO6HzfRz/1CKmPX3l/+KP15/FFsKUjY=";
              };

              cargoSha256 = "sha256-IWCMtJZEADFebqQYe3f9pWoJvhDCpdBuRW6bB7R9K8Y=";

              cargoDeps = prev.cargoDeps.overrideAttrs (final.lib.const {
                name = "alacritty-${version}-vendor.tar.gz";
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

      machines = [ "lavienrose" "zeta-gundam" ];
      forAllMachines = genAttrs machines;

      users = [ "ross" ];
      forAllUsers = genAttrs users;

      darwinMachines = [];
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
            ./system/default.nix
            ./system/linux/default.nix
            ./devices/${machine}/default.nix
            nur-modules.repos.ilya-fedin.modules.flatpak-fonts
            nur-modules.repos.ilya-fedin.modules.flatpak-icons
          ];
        }));
    };
}
