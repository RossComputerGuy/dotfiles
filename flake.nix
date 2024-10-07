{
  description = "A Flake of my NixOS machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    # <https://github.com/nix-systems/nix-systems>
    systems.url = "github:nix-systems/default-linux";
    nur.url = "github:nix-community/NUR";
    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?ref=main&rev=0c7a7e2d569eeed9d6025f3eef4ea0690d90845d&submodules=1";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    ags.url = "github:Aylur/ags";
    hycov.url = "github:DreamMaoMao/hycov/0.41.2.1";
    shuba-cursors = {
      url = "github:RossComputerGuy/shuba-cursors";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-apple-silicon = {
      url = "github:tpwrules/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    darwin.url = "github:lnl7/nix-darwin/master";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  nixConfig = rec {
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://cache.garnix.io"
    ];
    trusted-substituters = substituters;
    fallback = true;
  };

  outputs =
    {
      self,
      nur,
      home-manager,
      nixpkgs,
      darwin,
      nixos-apple-silicon,
      hyprland,
      ags,
      hycov,
      shuba-cursors,
      nixos-hardware,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      overlays = {
        nur = nur.overlay;
        apple-silicon = nixos-apple-silicon.overlays.default;

        hyprland = hyprland.overlays.default;
        default = (
          final: prev: {
            path = nixpkgs;

            shuba-cursors = final.stdenv.mkDerivation {
              pname = "shuba-cursors";
              version = "git-${inputs.shuba-cursors.shortRev or "dirty"}";

              src = lib.cleanSource inputs.shuba-cursors;

              installPhase = ''
                install -dm 755 $out/share/icons/Shuba
                cp -r cursors $out/share/icons/Shuba/cursors
                cp index.theme $out/share/icons/Shuba/index.theme
              '';
            };

            ibus = prev.ibus.override { withWayland = true; };

            wayland = prev.wayland.overrideAttrs (
              self: super: {
                version = "1.23.1";

                patches = [ ];
                src = final.fetchurl {
                  url =
                    with self;
                    "https://gitlab.freedesktop.org/wayland/wayland/-/releases/${version}/downloads/${pname}-${version}.tar.xz";
                  hash = "sha256-hk+yqDmeLQ7DnVbp2bdTwJN3W+rcYCLOgfRBkpqB5e0=";
                };
              }
            );

            libinput = prev.libinput.overrideAttrs (
              self: super: {
                version = "1.26.0";

                src = final.fetchFromGitLab {
                  domain = "gitlab.freedesktop.org";
                  owner = "libinput";
                  repo = "libinput";
                  rev = self.version;
                  hash = "sha256-mlxw4OUjaAdgRLFfPKMZDMOWosW9yKAkzDccwuLGCwQ=";
                };
              }
            );

            hycov = prev.callPackage "${hycov}/default.nix" {
              inherit (final) hyprland;
              stdenv = prev.gcc13Stdenv;
            };

            box64 = prev.box64.overrideAttrs (
              f: p: {
                version = "0.2.8";
                src = prev.fetchFromGitHub {
                  owner = "ptitSeb";
                  repo = "box64";
                  rev = "v${f.version}";
                  hash = "sha256-P+m+JS3THh3LWMZYW6BQ7QyNWlBuL+hMcUtUbpMHzis=";
                };
              }
            );

            rtl8723bs-firmware = prev.runCommand "rtl8723bs-firmware" { } ''
              mkdir -p $out/lib/firmware
            '';
          }
        );
      };

      systems = [
        "aarch64-darwin"
        "riscv64-linux"
        "aarch64-linux"
        "x86_64-linux"
      ];
      nixpkgsFor = lib.genAttrs systems (
        system:
        import nixpkgs.outPath {
          inherit system;
          overlays = (builtins.attrValues overlays);
          config = {
            allowUnfree = true;
          };
        }
      );

      machines = {
        lavienrose = "x86_64-linux";
        zeta-gundam = "x86_64-linux";
        zeta3a = "aarch64-linux";
        hizack-b = "aarch64-linux";
        jegan = "riscv64-linux";
      };
      forAllMachines = func: lib.mapAttrs func machines;

      users = [ "ross" ];
      forAllUsers =
        func:
        lib.listToAttrs (
          lib.lists.flatten (
            lib.map (
              system: lib.map (user: lib.nameValuePair ("${system}/${user}") (func system user)) users
            ) systems
          )
        );

      darwinMachines = {
        "Hizack" = "aarch64-darwin";
      };
      forAllDarwinMachines = func: lib.mapAttrs func darwinMachines;

      homeManagerModules = [
        hyprland.homeManagerModules.default
        ags.homeManagerModules.default
      ];
    in
    {
      inherit overlays;
      legacyPackages = nixpkgsFor;

      packages = lib.mapAttrs (system: pkgs: rec {
        ags =
          (pkgs.callPackage "${inputs.ags}/nix" {
            version = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile "${inputs.ags}/version");
            inherit (pkgs.gnome) gnome-bluetooth;
          }).overrideAttrs
            (
              self: prev: {
                meta = prev.meta // {
                  platforms = lib.platforms.linux;
                };
              }
            );

        inherit (pkgs) hyprland hyprland-legacy-renderer;
      }) nixpkgsFor;

      homeConfigurations = forAllUsers (
        system: user:
        home-manager.lib.homeManagerConfiguration (rec {
          pkgs = nixpkgsFor.${system};
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = [
            ./users/${user}/home.nix
            ./users/${user}/home-${pkgs.targetPlatform.parsed.kernel.name}.nix
          ] ++ homeManagerModules;
        })
      );

      darwinConfigurations = forAllDarwinMachines (
        machine: system:
        darwin.lib.darwinSystem {
          inherit system;
          pkgs = nixpkgsFor.${system};
          inputs = {
            inherit darwin nixpkgs;
          };
          modules = [
            home-manager.darwinModules.default
            ./system/default.nix
            ./system/darwin.nix
            ./devices/${machine}/default.nix
          ];
        }
      );

      nixosConfigurations = forAllMachines (
        machine: system:
        lib.nixosSystem (rec {
          inherit system;
          pkgs = nixpkgsFor.${system};
          specialArgs = {
            inherit inputs;
          };
          modules =
            let
              nur-modules = import nur.outPath {
                pkgs = nixpkgsFor.${system};
                nurpkgs = nixpkgsFor.${system};
              };
            in
            [
              {
                documentation.nixos.enable = false;
                home-manager.sharedModules = homeManagerModules;
              }
              home-manager.nixosModules.default
              ./system/default.nix
              ./system/linux/default.nix
              ./devices/${machine}/default.nix
              nur-modules.repos.ilya-fedin.modules.flatpak-fonts
              nur-modules.repos.ilya-fedin.modules.flatpak-icons
            ];
        })
      );
    };
}
