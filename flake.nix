{
  description = "A Flake of my NixOS machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";
    # <https://github.com/nix-systems/nix-systems>
    systems.url = "github:nix-systems/default-linux";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-cosmic = {
      url = "github:ninelore/nixpkgs-cosmic-unstable?ref=pull/27/head";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    shuba-cursors = {
      url = "github:RossComputerGuy/shuba-cursors";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    disko.url = "github:nix-community/disko";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        systems.follows = "systems";
      };
    };
  };

  nixConfig = rec {
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      #"cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
    ];
    substituters = [
      "https://cache.nixos.org"
      #"https://cache.garnix.io"
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
      nixpkgs-unstable,
      home-manager-unstable,
      darwin,
      nixos-apple-silicon,
      nixos-cosmic,
      shuba-cursors,
      nixos-hardware,
      disko,
      determinate,
      nixvim,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      overlays = {
        nur = nur.overlays.default;
        apple-silicon = nixos-apple-silicon.overlays.default;
        default = (
          final: prev: {
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

            obs-studio-plugins = prev.obs-studio-plugins // {
              wlrobs = prev.obs-studio-plugins.wlrobs.overrideAttrs (f: p: {
                meta = p.meta // {
                  platforms = [ "aarch64-linux" "x86_64-linux" ];
                };
              });
              obs-urlsource = prev.obs-studio-plugins.obs-urlsource.overrideAttrs (f: p: {
                meta = p.meta // {
                  platforms = [ "aarch64-linux" "x86_64-linux" ];
                };
              });
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
        zeta3a = "aarch64-linux";
        hizack-b = "aarch64-linux";
        jegan = "riscv64-linux";
        age = "aarch64-linux";
        jeda = "aarch64-linux";
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

      machineConfig = {
        jegan = {
          nixpkgs = nixpkgs-unstable;
          home-manager = home-manager-unstable;
        };
        hizack-b = {
          nixpkgs = nixpkgs-unstable;
          home-manager = home-manager-unstable;
        };
        zeta3a = {
          nixpkgs = nixpkgs-unstable;
          home-manager = home-manager-unstable;
        };
        jeda = {
          nixpkgs = nixpkgs-unstable;
          home-manager = home-manager-unstable;
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
        nixvim.homeModules.nixvim
      ];

      mkMachine =
        machine: localSystem: crossSystem: extraModules:
        let
          cfg = machineConfig.${machine} or { };
        in
        (cfg.nixpkgs or inputs.nixpkgs).lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules =
            [
              {
                documentation.nixos.enable = false;
                home-manager.sharedModules = homeManagerModules;
                nixpkgs = {
                  overlays = (builtins.attrValues overlays);
                  inherit crossSystem localSystem;
                  config.allowUnfree = true;
                };
              }
              (cfg.home-manager or inputs.home-manager).nixosModules.default
              ./system/default.nix
              ./system/linux/default.nix
              ./devices/${machine}/default.nix
              nixos-cosmic.nixosModules.default
              determinate.nixosModules.default
              nixvim.nixosModules.nixvim
            ]
            ++ (cfg.extraModules or [ ])
            ++ extraModules;
        };
    in
    {
      inherit overlays;
      legacyPackages = nixpkgsFor;

      packages = lib.genAttrs systems (
        localSystem:
        forAllMachines (
          machine: crossSystem:
          let
            cfg = machineCross.${machine} or { };
            nixos = mkMachine machine { system = localSystem; } { system = crossSystem; } (
              cfg.extraModules or [ ]
            );
          in
          nixos.config.system.build.${cfg.output or "toplevel"}
          // {
            inherit nixos;
          }
        )
      );

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
        machine: system: mkMachine machine { inherit system; } null [ ]
      );
    };
}
