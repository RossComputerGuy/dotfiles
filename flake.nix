{
  description = "A Flake of my NixOS machines";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.nur.url = "github:nix-community/NUR";
  inputs.hyprland.url = "git+https://github.com/hyprwm/Hyprland?ref=main&rev=918d8340afd652b011b937d29d5eea0be08467f5&submodules=1";
  inputs.ags.url = "github:Aylur/ags";
  inputs.hycov.url = "github:DreamMaoMao/hycov/0.41.2.1";
  inputs.shuba-cursors = {
    url = "github:RossComputerGuy/shuba-cursors";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.nixos-apple-silicon = {
    url = "github:tpwrules/nixos-apple-silicon";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.home-manager.url = "github:nix-community/home-manager/release-24.05";
  inputs.darwin.url = "github:lnl7/nix-darwin/master";
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/master";

  nixConfig = rec {
    trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
    substituters = [ "https://cache.nixos.org" "https://cache.garnix.io" ];
    trusted-substituters = substituters;
    fallback = true;
  };

  outputs = { self, nur, home-manager, nixpkgs, darwin, nixos-apple-silicon, hyprland, ags, hycov, shuba-cursors, nixos-hardware }@inputs:
    with nixpkgs.lib;
    let
      inherit (home-manager.lib) hm homeManagerConfiguration;

      overlays = {
        nur = nur.overlay;
        apple-silicon = nixos-apple-silicon.overlays.default;

        hyprland = hyprland.overlays.default;
        default = (final: prev: {
          path = nixpkgs;

          shuba-cursors = shuba-cursors.packages.${final.system}.default;

          ibus = prev.ibus.override {
            withWayland = true;
          };

          hycov = prev.callPackage "${hycov}/default.nix" {
            inherit (final) hyprland;
            stdenv = prev.gcc13Stdenv;
          };

          box64 = prev.box64.overrideAttrs (f: p: {
            version = "0.2.8";
            src = prev.fetchFromGitHub {
              owner = "ptitSeb";
              repo = "box64";
              rev = "v${f.version}";
              hash = "sha256-P+m+JS3THh3LWMZYW6BQ7QyNWlBuL+hMcUtUbpMHzis=";
            };
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
            modules = [
              ./users/${user}/home.nix
              ./users/${user}/home-${pkgs.targetPlatform.parsed.kernel.name}.nix
              hyprland.homeManagerModules.default
              ags.homeManagerModules.default
            ];
          });
        } // (optionalAttrs pkgs.targetPlatform.isDarwin {
          darwinConfigurations = forAllDarwinMachines (machine:
            darwin.lib.darwinSystem {
              inherit system pkgs;
              inputs = {
                inherit darwin nixpkgs;
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
        nixpkgs.lib.nixosSystem (rec {
          system = "x86_64-linux";
          pkgs = nixpkgsFor.${system};
          modules = let
            nur-modules = import nur.outPath {
              pkgs = nixpkgsFor.${system};
              nurpkgs = nixpkgsFor.${system};
            };
          in [
            {
              documentation.nixos.enable = false;
              home-manager.sharedModules = [
                hyprland.homeManagerModules.default
                ags.homeManagerModules.default
              ];
            }
            home-manager.nixosModules.default
            ./system/default.nix
            ./system/linux/default.nix
            ./devices/${machine}/default.nix
            nur-modules.repos.ilya-fedin.modules.flatpak-fonts
            nur-modules.repos.ilya-fedin.modules.flatpak-icons
          ];
        })) // {
          "hizack-b" = nixpkgs.lib.nixosSystem (rec {
            system = "aarch64-linux";
            pkgs = nixpkgsFor.${system}.appendOverlays [
              (final: prev: {
                tbb = prev.callPackage ./pkgs/development/libraries/tbb/2020_3.nix {};
                glew110 = prev.glew110.overrideAttrs (f: p: {
                  patchPhase = ''
                    sed -i "s|CC = cc|CC = $CC|" config/Makefile.linux
                    sed -i "s|LD = cc|LD = $CC|" config/Makefile.linux
                  '' + p.patchPhase;
                });
              })
              (final: prev: {
                steam = prev.callPackage "${nixpkgs}/pkgs/games/steam/fhsenv.nix" (let
                  makeWrapped = steamArch: pkgs: pkgs.callPackage "${nixpkgs}/pkgs/games/steam/runtime-wrapped.nix" {
                    inherit steamArch;
                    steam-runtime = pkgs.callPackage "${nixpkgs}/pkgs/games/steam/runtime.nix" {};
                  };
                in {
                  buildFHSEnv = final.pkgsCross.gnu64.callPackage ./pkgs/build-support/build-fhsenv-bubblewrap/default.nix {
                    inherit (final.pkgsCross.gnu64) pkgsi686Linux;
                  };
                  glxinfo-i686 = final.pkgsCross.gnu64.pkgsi686Linux.glxinfo;
                  steam-runtime-wrapped-i686 = makeWrapped "i386" final.pkgsCross.gnu64.pkgsi686Linux;
                  steam-runtime-wrapped = makeWrapped "amd64" final.pkgsCross.gnu64;
                  steam = final.pkgsCross.gnu64.callPackage "${nixpkgs}/pkgs/games/steam/steam.nix" {};
                });
              })
            ];
            modules = let
              machine = "hizack-b";
              nur-modules = import nur.outPath {
                pkgs = nixpkgsFor.${system};
                nurpkgs = nixpkgsFor.${system};
              };
            in [
              {
                documentation.nixos.enable = false;
                home-manager.sharedModules = [
                  hyprland.homeManagerModules.default
                  ags.homeManagerModules.default
                ];

                disabledModules = [
                  "${nixpkgs}/nixos/modules/programs/steam.nix"
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
          "jegan" = nixpkgs.lib.nixosSystem (rec {
            system = "riscv64-linux";
            pkgs = nixpkgsFor.${system};
            modules = let
              machine = "jegan";
              nur-modules = import nur.outPath {
                pkgs = nixpkgsFor.${system};
                nurpkgs = nixpkgsFor.${system};
              };
            in [
              {
                documentation.nixos.enable = false;
                home-manager.sharedModules = [
                  hyprland.homeManagerModules.default
                  ags.homeManagerModules.default
                ];
              }
              home-manager.nixosModules.default
              ./system/default.nix
              ./system/linux/default.nix
              ./devices/${machine}/default.nix
              nur-modules.repos.ilya-fedin.modules.flatpak-fonts
              nur-modules.repos.ilya-fedin.modules.flatpak-icons
            ];
          });
          "zeta3a" = nixpkgs.lib.nixosSystem (rec {
            system = "aarch64-linux";
            pkgs = nixpkgsFor.${system};
            modules = let
              machine = "zeta3a";
              nur-modules = import nur.outPath {
                pkgs = nixpkgsFor.${system};
                nurpkgs = nixpkgsFor.${system};
              };
            in [
              {
                documentation.nixos.enable = false;
                home-manager.sharedModules = [
                  hyprland.homeManagerModules.default
                  ags.homeManagerModules.default
                ];
              }
              home-manager.nixosModules.default
              ./system/default.nix
              ./system/linux/default.nix
              ./devices/${machine}/default.nix
              nur-modules.repos.ilya-fedin.modules.flatpak-fonts
              nur-modules.repos.ilya-fedin.modules.flatpak-icons
            ];
          });
        };
    };
}
