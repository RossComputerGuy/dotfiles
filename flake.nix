{
  description = "A Flake of my NixOS machines";

  inputs.expidus-sdk = {
    url = github:ExpidusOS/sdk;
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-23.11;
  inputs.nixpkgs-unstable.url = github:NixOS/nixpkgs/nixos-unstable;
  inputs.nixpkgs-firefox-119.url = github:NixOS/nixpkgs/7df1b3e9fa6ace9b2dff8f97952b12c17291cf1e;
  inputs.nur.url = github:nix-community/NUR;
  inputs.hyprland.url = github:hyprwm/Hyprland;
  inputs.ags.url = github:Aylur/ags;
  inputs.hycov.url = github:DreamMaoMao/hycov;
  inputs.shuba-cursors = {
    url = github:RossComputerGuy/shuba-cursors;
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.nixos-apple-silicon = {
    # url = github:tpwrules/nixos-apple-silicon;
    url = github:yu-re-ka/nixos-m1/nixos-unstable-fixes;
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.home-manager.url = github:nix-community/home-manager/release-23.11;
  inputs.darwin.url = github:lnl7/nix-darwin/master;

  nixConfig = rec {
    trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
    substituters = [ "https://cache.nixos.org" "https://cache.garnix.io" ];
    trusted-substituters = substituters;
    fallback = true;
  };

  outputs = { self, expidus-sdk, nur, home-manager, nixpkgs, nixpkgs-unstable, darwin, nixos-apple-silicon, nixpkgs-firefox-119, hyprland, ags, hycov, shuba-cursors }@inputs:
    with expidus-sdk.lib;
    let
      inherit (home-manager.lib) hm homeConfiguration;

      overlays = {
        nur = nur.overlay;
        apple-silicon = nixos-apple-silicon.overlays.default;

        wlroots_17 = (final: prev: {
          wlroots = (prev.callPackage "${nixpkgs-unstable}/pkgs/development/libraries/wlroots" {}).wlroots_0_17;
        });

        hyprland = hyprland.overlays.default;
        default = (final: prev: {
          path = nixpkgs;

          shuba-cursors = shuba-cursors.packages.${final.system}.default;
          inherit (nixpkgs-unstable.legacyPackages.${final.system}) noto-fonts-color-emoji openscad;

          libdrm = prev.callPackage "${nixpkgs-unstable}/pkgs/development/libraries/libdrm" {};

          libsecret = prev.libsecret.overrideAttrs (f: p: {
            doCheck = false;
          });

          xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (f: p: {
            doCheck = false;

            nativeBuildInputs = p.nativeBuildInputs ++ (with prev; [
              python3Packages.pytest
              python3Packages.python-dbusmock
            ]);
          });

          #inherit (nixpkgs-unstable.legacyPackages.${final.system}) wlroots libdrm ffmpeg-headless
          #  ostree gnome fwupd fwup libsForQt5 qt5 libsForQt6 qt6 fcitx5 gcr openscad prismlauncher
          #  pipewire wireplumber xdg-desktop-portal ffmpeg_4-full ffmpeg_4-headless ffmpeg_4 xorg
          #  upower noto-fonts noto-fonts-color-emoji samba webkitgtk webkitgtk_4_1 webkitgtk_6_0
          #  networkmanager networkmanager-vpnc networkmanager-sstp networkmanager-l2tp networkmanager-openconnect
          #  fcitx5-with-addons fcitx5-gtk fcitx5-mozc fcitx5-authy waydroid;

          #mesa = nixpkgs-unstable.legacyPackages.${final.system}.mesa.overrideAttrs (f: p: rec {
          #  version = "24.0.0-rc1";
          #  name = "mesa-${version}";

          #  patches = let
          #    basePath = "${nixpkgs-unstable}/pkgs/development/libraries/mesa";
          #  in [
          #    "${basePath}/musl.patch"
          #    "${basePath}/opencl.patch"
          #    "${basePath}/disk_cache-include-dri-driver-path-in-cache-key.patch"
          #    ./mesa-24.0.0-devel.patch
          #  ];

          #  src = final.fetchurl {
          #    urls = [
          #      "https://archive.mesa3d.org/mesa-${version}.tar.xz"
          #      "https://mesa.freedesktop.org/archive/mesa-${version}.tar.xz"
          #      "ftp://ftp.freedesktop.org/pub/mesa/mesa-${version}.tar.xz"
          #      "ftp://ftp.freedesktop.org/pub/mesa/${version}/mesa-${version}.tar.xz"
          #      "ftp://ftp.freedesktop.org/pub/mesa/older-versions/${versions.major version}.x/${version}/mesa-${version}.tar.xz"
          #    ];
          #    #hash = "sha256-UYMHwAV/o87otY33i+Qx1N9ar6ftxg0JJ4stegqA87Q=";
          #    hash = "sha256-hvsZnrrNlztnUjgdbTnyOLg+V749aVeMOCQ1OkCujO4=";
          #  };
          #});

          ibus = prev.ibus.override {
            withWayland = true;
          };

          hycov = prev.callPackage "${hycov}/default.nix" {
            inherit (final) hyprland;
            stdenv = prev.gcc13Stdenv;
          };

          inherit (nixpkgs-unstable.legacyPackages.${final.system}) qemu;
          inherit (nixpkgs-firefox-119.legacyPackages.${final.system}) firefox;

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
              hyprland.homeManagerModules.default
              ags.homeManagerModules.default
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
                home-manager.sharedModules = [
                  hyprland.homeManagerModules.default
                  ags.homeManagerModules.default
                ];

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
