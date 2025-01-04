{
  description = "A Flake of my NixOS machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    # <https://github.com/nix-systems/nix-systems>
    systems.url = "github:nix-systems/default-linux";
    nur.url = "github:nix-community/NUR";
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    shuba-cursors = {
      url = "github:RossComputerGuy/shuba-cursors";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-apple-silicon = {
      url = "github:tpwrules/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    darwin.url = "github:lnl7/nix-darwin/master";
    nixos-hardware.url = "github:RossComputerGuy/nixos-hardware/feat/vf2-improve";
  };

  nixConfig = rec {
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://cache.garnix.io"
      "https://cosmic.cachix.org"
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
      nixos-cosmic,
      shuba-cursors,
      nixos-hardware,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      overlays = {
        nur = nur.overlays.default;
        apple-silicon = nixos-apple-silicon.overlays.default;
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

            bazel_7 = prev.bazel_7.override { enableNixHacks = false; };
            bazel = prev.bazel.override { enableNixHacks = false; };

            tokyonight-gtk-theme = prev.tokyonight-gtk-theme.override {
              gnome-shell = final.writeShellScriptBin "gnome-shell" ''
                echo "GNOME Shell ${final.gnome-shell.version}"
              '';
            };
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

      machineCross = {
        jegan = {
          extraModules = [
            "${nixos-hardware}/starfive/visionfive/v2/sd-image-installer.nix"
          ];
          output = "sdImage";
        };
      };

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
      ];

      mkMachine =
        machine: localSystem: crossSystem: extraModules:
        lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            {
              documentation.nixos.enable = false;
              home-manager.sharedModules = homeManagerModules;
              nixpkgs = {
                overlays = (builtins.attrValues overlays);
                inherit crossSystem localSystem;
                config.allowUnfree = true;
              };
            }
            home-manager.nixosModules.default
            ./system/default.nix
            ./system/linux/default.nix
            ./devices/${machine}/default.nix
            nixos-cosmic.nixosModules.default
          ] ++ extraModules;
        };
    in
    {
      inherit overlays;
      legacyPackages = nixpkgsFor;

      packages = lib.mapAttrs (
        localSystem: pkgs:
        forAllMachines (
          machine: crossSystem:
          let
            cfg = machineCross.${machine} or {};
          in
          (mkMachine machine { system = localSystem; } { system = crossSystem; } (cfg.extraModules or []))
          .config.system.build.${cfg.output or "toplevel"}
        )
      ) nixpkgsFor;

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
        machine: system: mkMachine machine { inherit system; } { inherit system; } [ ]
      );
    };
}
