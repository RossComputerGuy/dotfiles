{
  description = "A Flake of my NixOS machines";

  inputs.expidus-sdk.url = github:ExpidusOS/sdk;

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-23.05;
  inputs.nixpkgs-unstable.url = github:NixOS/nixpkgs/nixos-unstable;
  inputs.nur.url = github:nix-community/NUR;
  inputs.nixos-apple-silicon.url = github:tpwrules/nixos-apple-silicon;
  inputs.home-manager.url = github:nix-community/home-manager/release-23.05;
  inputs.darwin.url = github:lnl7/nix-darwin/master;

  nixConfig = rec {
    trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
    substituters = [ "https://cache.nixos.org" "https://cache.garnix.io" ];
    trusted-substituters = substituters;
    fallback = true;
  };

  outputs = { self, expidus-sdk, nur, home-manager, nixpkgs, nixpkgs-unstable, darwin, nixos-apple-silicon }@inputs:
    with expidus-sdk.lib;
    let
      inherit (home-manager.lib) hm homeConfiguration;

      overlays = {
        nur = nur.overlay;
        apple-silicon = nixos-apple-silicon.overlays.default;
        default = (final: prev: {
          path = nixpkgs;

          waydroid = prev.callPackage "${nixpkgs-unstable}/pkgs/os-specific/linux/waydroid/default.nix" {};
          inherit (nixpkgs-unstable.legacyPackages.${final.system}) qemu;

          "pipewire-0.3.84" = nixpkgs-unstable.legacyPackages.${final.system}.pipewire;
          wireplumber = nixpkgs-unstable.legacyPackages.${final.system}.wireplumber;

			    alsa-ucm-conf-asahi = prev.callPackage ./devices/hizack-b/alsa-ucm-conf-asahi.nix {
				    inherit (final) alsa-ucm-conf;
			    };

			    alsa-lib-asahi = prev.alsa-lib.override {
				    alsa-ucm-conf = final.alsa-ucm-conf-asahi;
			    };

          box64 = prev.box64.overrideAttrs (f: p: {
            cmakeFlags = p.cmakeFlags ++ [
              "-DPAGE16K=1"
            ];
          });

          rtl8723bs-firmware = prev.runCommand "rtl8723bs-firmware" {} ''
            mkdir -p $out/lib/firmware
          '';
        });
      };

      nixpkgsFor = genAttrs [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ] (system:
        import nixpkgs.outPath {
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
          homeManagerConfiguration {
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
              inherit system pkgs;
              inputs = {
                inherit darwin;
                nixpkgs = expidus-sdk // {
                  legacyPackages = nixpkgsFor;
                  inherit (nixpkgs) outPath;
                };
              };
              modules = [
                home-manager.darwinModules.default
                ./system/default.nix
                ./system/darwin.nix
                ./devices/${machine}/default.nix
              ];
            });
        })) nixpkgsFor;

      nixosConfigurations = forAllMachines (machine:
        import "${nixpkgs}/nixos/lib/eval-config.nix" (rec {
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
            home-manager.nixosModules.default
            ./system/default.nix
            ./system/linux/default.nix
            ./devices/${machine}/default.nix
            nur-modules.repos.ilya-fedin.modules.flatpak-fonts
            nur-modules.repos.ilya-fedin.modules.flatpak-icons
          ];
        })) // {
          "hizack-b" = import "${nixpkgs}/nixos/lib/eval-config.nix" (rec {
            system = "aarch64-linux";
            inherit (expidus-sdk) lib;
            pkgs = nixpkgsFor.${system};
            modules = let
              machine = "hizack-b";
              nur-modules = import nur.outPath {
                pkgs = nixpkgsFor.${system};
                nurpkgs = nixpkgsFor.${system};
              };
            in [
              {
                documentation.nixos.enable = false;

                disabledModules = [
                  "services/desktops/pipewire/pipewire.nix"
                ];

                imports = [
                  "${nixpkgs-unstable}/nixos/modules/services/desktops/pipewire/pipewire.nix"
                ];
              }
              home-manager.nixosModules.default
              ./system/default.nix
              ./system/linux/default.nix
              ./devices/${machine}/default.nix
              nur-modules.repos.ilya-fedin.modules.flatpak-fonts
              nur-modules.repos.ilya-fedin.modules.flatpak-icons
              nixos-apple-silicon.nixosModules.default
            ];
          });
        };
    };
}
