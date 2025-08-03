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
      url = "github:lilyinstarlight/nixos-cosmic?ref=pull/863/head";
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
      url = "github:nix-community/home-manager/release-24.11";
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

            openexr = prev.openexr.overrideAttrs (
              f: p: {
                doCheck = p.doCheck && !final.stdenv.hostPlatform.isRiscV64;
              }
            );

            ripgrep = prev.ripgrep.overrideAttrs (
              f: p: {
                doCheck = p.doCheck && !final.stdenv.hostPlatform.isRiscV64;
              }
            );

            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              (pythonFinal: pythonPrev: {
                hypothesis = pythonPrev.hypothesis.overrideAttrs (
                  f: p: {
                    doCheck = p.doCheck && !final.stdenv.hostPlatform.isRiscV64;
                  }
                );
              })
            ];

            libadwaita = prev.libadwaita.overrideAttrs (
              f: p: {
                doCheck = p.doCheck && !final.stdenv.hostPlatform.isRiscV64;
              }
            );

            libjxl = prev.libjxl.overrideAttrs (
              f: p: {
                doCheck = p.doCheck && !final.stdenv.hostPlatform.isRiscV64;
              }
            );

            tcp_wrappers = prev.tcp_wrappers.overrideAttrs (
              f: p: {
                patches =
                  p.patches
                  ++ lib.optional (final.stdenv.cc.isClang) ./pkgs/by-name/tc/tcp_wrappers/clang.diff;
              }
            );

            keyutils =
              if final.stdenv.hostPlatform.useLLVM then
                prev.keyutils.overrideAttrs (
                  f: p: {
                    NIX_LDFLAGS = "--undefined-version";
                  }
                )
              else
                prev.keyutils;

            util-linux = prev.util-linux.overrideAttrs (
              f: p: {
                configureFlags =
                  p.configureFlags
                  ++ lib.optional final.stdenv.hostPlatform.useLLVM "LDFLAGS=-Wl,--undefined-version";
              }
            );

            nfs-utils = prev.nfs-utils.overrideAttrs (
              f: p: {
                configureFlags =
                  p.configureFlags
                  ++ lib.optional final.stdenv.hostPlatform.useLLVM "CFLAGS=-Wno-format-nonliteral";
              }
            );

            obs-studio-plugins = prev.obs-studio-plugins // {
              wlrobs = prev.obs-studio-plugins.wlrobs.overrideAttrs (f: p: {
                meta = p.meta // {
                  platforms = [ "aarch64-linux" "x86_64-linux" ];
                };
              });
            };

            systemd =
              if final.stdenv.hostPlatform.useLLVM then
                prev.systemd.override {
                  withHomed = false;
                  withCryptsetup = false;
                  withRepart = false;
                  withFido2 = false;
                }
              else
                prev.systemd;

            xonsh = if final.stdenv.hostPlatform.isRiscV64 then final.emptyDirectory else prev.xonsh;

            nodejs_22 =
              if final.stdenv.hostPlatform.isRiscV64 then
                (prev.callPackage "${nixpkgs}/pkgs/development/web/nodejs/nodejs.nix"
                  {
                    python = final.python3;
                  }
                  {
                    version = "22.13.1";
                    sha256 = "cfce282119390f7e0c2220410924428e90dadcb2df1744c0c4a0e7baae387cc2";
                    patches = [
                      "${nixpkgs}/pkgs/development/web/nodejs/configure-emulator.patch"
                      "${nixpkgs}/pkgs/development/web/nodejs/configure-armv6-vfpv2.patch"
                      "${nixpkgs}/pkgs/development/web/nodejs/disable-darwin-v8-system-instrumentation-node19.patch"
                      "${nixpkgs}/pkgs/development/web/nodejs/bypass-darwin-xcrun-node16.patch"
                      "${nixpkgs}/pkgs/development/web/nodejs/node-npm-build-npm-package-logic.patch"
                      "${nixpkgs}/pkgs/development/web/nodejs/use-correct-env-in-tests.patch"
                      "${nixpkgs}/pkgs/development/web/nodejs/bin-sh-node-run-v22.patch"
                      # Those reverts are due to a mismatch with the libuv version used upstream
                      (final.fetchpatch2 {
                        url = "https://github.com/nodejs/node/commit/84fe809535b0954bbfed8658d3ede8a2f0e030db.patch?full_index=1";
                        hash = "sha256-C1xG2K9Ejofqkl/vKWLBz3vE0mIPBjCdfA5GX2wlS0I=";
                        revert = true;
                      })
                      (final.fetchpatch2 {
                        url = "https://github.com/nodejs/node/commit/dcbc5fbe65b068a90c3d0970155d3a68774caa38.patch?full_index=1";
                        hash = "sha256-Q7YrooolMjsGflTQEj5ra6hRVGhMP6APaydf1MGH54Q=";
                        revert = true;
                        excludes = [ "doc/*" ];
                      })
                      (final.fetchpatch2 {
                        url = "https://github.com/nodejs/node/commit/ec867ac7ce4e4913a8415eda48a7af9fc226097d.patch?full_index=1";
                        hash = "sha256-zfnHxC7ZMZAiu0/6PsX7RFasTevHMETv+azhTZnKI64=";
                        revert = true;
                        excludes = [ "doc/*" ];
                      })
                      (final.fetchpatch2 {
                        url = "https://github.com/nodejs/node/commit/f97865fab436fba24b46dad14435ec4b482243a2.patch?full_index=1";
                        hash = "sha256-o5aPQqUXubtJKMX28jn8LdjZHw37/BqENkYt6RAR3kY=";
                        revert = true;
                      })
                      (final.fetchpatch2 {
                        url = "https://github.com/nodejs/node/commit/54d55f2337ebe04451da770935ad453accb147f9.patch?full_index=1";
                        hash = "sha256-gmIyiSyNzC3pClL1SM2YicckWM+/2tsbV1xv2S3d5G0=";
                        revert = true;
                      })
                      # FIXME: remove after a minor point release
                      (final.fetchpatch2 {
                        url = "https://github.com/nodejs/node/commit/49acdc8748fe9fe83bc1b444e24c456dff00ecc5.patch?full_index=1";
                        hash = "sha256-iK7bj4KswTeQ9I3jJ22ZPTsvCU8xeGGXEOo43dxg3Mk=";
                      })
                      (final.fetchpatch2 {
                        url = "https://github.com/nodejs/node/commit/d0ff34f4b690ad49c86b6df8fd424f39d183e1a6.patch?full_index=1";
                        hash = "sha256-ezcCrg7UwK091pqYxXJn4ay9smQwsrYeMO/NBE7VaM8=";
                      })
                      # test-icu-env is failing on ICU 74.2
                      # FIXME: remove once https://github.com/nodejs/node/pull/56661 is included in a next release
                      (final.fetchpatch2 {
                        url = "https://github.com/nodejs/node/commit/a364ec1d1cbbd5a6d20ee54d4f8648dd7592ebcd.patch?full_index=1";
                        hash = "sha256-EL1NgCBzz5O1spwHgocLm5mkORAiqGFst0N6pc3JvFg=";
                        revert = true;
                      })
                    ];
                  }
                ).overrideAttrs
                  (
                    f: p: {
                      doCheck = false;
                      doInstallCheck = false;
                    }
                  )
              else
                prev.nodejs_22;
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
