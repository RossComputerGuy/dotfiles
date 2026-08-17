{
  description = "A Flake of my NixOS machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    # <https://github.com/nix-systems/nix-systems>
    systems.url = "github:nix-systems/default-linux";
    nur = {
      url = "github:nix-community/NUR";
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
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
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
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Puts qBittorrent in a network namespace whose only route out is the
    # Mullvad tunnel. It has no inputs of its own.
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    nixos-vault-service = {
      url = "github:DeterminateSystems/nixos-vault-service";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nur.follows = "nur";
        systems.follows = "systems";
      };
    };
    # The palette, as sources and not as a package. modules/theme.nix used to
    # name a file inside pkgs.base16-schemes, and stylix reads that file while
    # it evaluates. So Nix had to build base16-schemes for the machine's own
    # platform before it could evaluate the machine at all, and a riscv64
    # machine could then only be evaluated on riscv64 hardware. A source path
    # needs no build, so every machine now evaluates from any machine.
    #
    # The repository is "schemes" and the files are below base16/. The nixpkgs
    # package renames that directory to share/themes, which is why the old path
    # looked different.
    base16-schemes = {
      url = "github:tinted-theming/schemes";
      flake = false;
    };
  };

  nixConfig = rec {
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      #"cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
      "argama-1:D/CZ1iVEV+tjTUcYklCVGGhOkxHtx6M8B5j6hBYuSEk="
    ];
    substituters = [
      "https://cache.nixos.org"
      #"https://cache.garnix.io"
      "https://cosmic.cachix.org"
      # Plain HTTP on purpose. The Nix daemon needs a certificate authority in
      # its trust store before it starts, and OpenBao gives a machine argama's
      # authority long after that. TLS adds nothing here either, because every
      # store path carries a signature which the key above checks. A changed
      # byte on the wire fails that check, so the transport carries no trust.
      #
      # The name resolves through argama's own DNS only. A machine that cannot
      # reach it logs a warning for each query and carries on, because fallback
      # is true below.
      "http://cache.argama.nix"
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
      shuba-cursors,
      nixos-hardware,
      disko,
      determinate,
      nixvim,
      lanzaboote,
      stylix,
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
              wlrobs = prev.obs-studio-plugins.wlrobs.overrideAttrs (
                f: p: {
                  meta = p.meta // {
                    platforms = [
                      "aarch64-linux"
                      "x86_64-linux"
                    ];
                  };
                }
              );
            };

            libdrm = prev.libdrm.override {
              withValgrind =
                !final.stdenv.hostPlatform.useLLVM
                && lib.meta.availableOn final.stdenv.hostPlatform final.valgrind-light;
            };

            linux-pam = prev.linux-pam.overrideAttrs (
              f: p: {
                env =
                  lib.optionalAttrs
                    (final.stdenv.cc.bintools.isLLVM && lib.versionAtLeast final.stdenv.cc.bintools.version "17")
                    {
                      NIX_LDFLAGS = "--undefined-version";
                    };
              }
            );

            nettle = prev.nettle.overrideAttrs (
              lib.optionalAttrs final.stdenv.hostPlatform.isStatic {
                CCPIC = "-fPIC";
              }
            );

            qemu-user = prev.qemu-user.overrideAttrs (
              f: p:
              lib.optionalAttrs final.stdenv.hostPlatform.isStatic {
                configureFlags = p.configureFlags ++ [ "--disable-pie" ];
              }
            );

            noto-fonts-color-emoji =
              (prev.noto-fonts-color-emoji.override {
                inherit (final.pkgsBuildBuild) nototools;
              }).overrideAttrs
                (
                  f: p: {
                    nativeBuildInputs = with final.buildPackages; [
                      imagemagick
                      zopfli
                      pngquant
                      which
                      python3Packages.fonttools
                    ];

                    depsBuildBuild =
                      p.depsBuildBuild
                      ++ (with final.pkgsBuildBuild; [
                        nototools
                      ]);
                  }
                );

            ostree = prev.ostree.override {
              withGjs = final.stdenv.hostPlatform == final.stdenv.buildPlatform;
            };

            ostree-full = prev.ostree-full.override {
              withGjs = final.stdenv.hostPlatform == final.stdenv.buildPlatform;
            };

            nixos-render-docs = prev.nixos-render-docs.overrideAttrs (
              f: p: {
                patches = [ ];
              }
            );

            # libapparmor 5.0.2 puts a variable length array in a union at block
            # scope, in self_syscall_enabled_init_once. GCC takes that as an
            # extension. Clang refuses it and says the extension will never be
            # supported. The replacement is the same constant the line above
            # assigns to total_size, so this only folds the value in place and
            # the code keeps its meaning.
            #
            # Only clang needs it. Applied to every compiler it rebuilds
            # libapparmor and then dbus, pcsclite, libfido2 and openssh above
            # it, none of which can come from a cache after that.
            libapparmor = prev.libapparmor.overrideAttrs (o: {
              postPatch =
                (o.postPatch or "")
                + lib.optionalString final.stdenv.cc.isClang ''
                  substituteInPlace src/kernel.c \
                    --replace-fail "char buff[total_size];" "char buff[sizeof(struct lsm_ctx) + 8];"
                '';
            });

            # fonttools fails 68 tests under pkgsLLVM, and each one compares a
            # float in text: it gets 0.037499999999999999 where it wants 0.0375.
            # pkgsLLVM is a crossSystem, so configure takes a --host argument,
            # and autoconf sets cross_compiling=yes because the argument is
            # there rather than because the platforms differ. Python then cannot
            # run its own test for short float repr and keeps the %.17g one.
            # nixpkgs still runs the checks, because it compares the platforms
            # and sees they match.
            #
            # Only pkgsLLVM needs this. That set has no cache anyway, while the
            # ordinary one does, and pythonPackagesExtensions rebuilds every
            # python package below it.
            #
            # zeta3a reaches it through boot.kernelPackages: nvidiaPackages
            # comes from the same set, and nvidia-settings pulls gtk+3, pango,
            # harfbuzz and fonttools after it.
            pythonPackagesExtensions =
              prev.pythonPackagesExtensions
              ++ lib.optional final.stdenv.hostPlatform.useLLVM (
                pyfinal: pyprev: {
                  fonttools = pyprev.fonttools.overridePythonAttrs (_: {
                    doCheck = false;
                  });
                }
              );
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
        argama = "aarch64-linux";
        zeta3a = "aarch64-linux";
        hizack-b = "aarch64-linux";
        jegan = "riscv64-linux";
        age = "aarch64-linux";
        jeda = "aarch64-linux";
        regz = "x86_64-linux";
        mu-gundam = "riscv64-linux";
      };
      forAllMachines = func: lib.mapAttrs func machines;

      # The machines Hydra builds every night, so argama holds their store paths
      # before anybody rebuilds. harmonia serves argama's own store and nothing
      # else, so a path argama has never seen cannot come from argama, and the
      # client goes to cache.nixos.org over the internet instead.
      #
      # These three are here because people rebuild them. The rest are left out
      # on purpose: jegan and mu-gundam are riscv64 and argama has no builder
      # for that architecture, and regz is x86_64 for the same reason. See
      # services.hydra.buildMachinesFiles in devices/argama/default.nix, which
      # is empty.
      cachedMachines = [
        "argama"
        "zeta3a"
        "hizack-b"
      ];

      machineCross = {
        jegan = {
          extraModules = [
            "${nixos-hardware}/starfive/visionfive/v2/sd-image-installer.nix"
          ];
          output = "sdImage";
        };
      };

      machineConfig = {
        # Only argama confines a service to a VPN namespace. Every machine gets
        # the Vault agent, because they all read their secrets from
        # vault.argama.nix.
        argama.extraModules = [
          inputs.vpn-confinement.nixosModules.default
        ];
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
        # Always present, on every home-manager path. Stylix's own auto import
        # only fires when the OS level stylix is enabled, which leaves cross
        # builds and nix-darwin without the module while modules/theme.nix
        # still sets stylix options. system/default.nix turns the auto import
        # off so this entry is never duplicated.
        stylix.homeModules.stylix
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
          modules = [
            {
              documentation.nixos.enable = false;
              home-manager.sharedModules = homeManagerModules;
              # modules/theme.nix is a home-manager module as well as a NixOS
              # one, and it names a file inside the base16-schemes input. The
              # NixOS side of home-manager passes none of the outer arguments
              # down, so without this the module has no inputs to read.
              # homeConfigurations below already does the same thing.
              home-manager.extraSpecialArgs = {
                inherit inputs;
              };
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
            nixvim.nixosModules.nixvim
            lanzaboote.nixosModules.lanzaboote
            stylix.nixosModules.stylix
            inputs.nixos-vault-service.nixosModules.nixos-vault-service
          ]
          # Determinate has no riscv64 support, so gate on the platform the
          # machine runs, which is crossSystem when there is one and localSystem
          # otherwise. The old test read crossSystem alone, and crossSystem is
          # null for every nixosConfigurations entry, so jegan and mu-gundam
          # took the module and failed with "attribute 'riscv64-linux' missing".
          # Only the cross outputs under packages ever passed.
          ++
            lib.optional ((crossSystem.system or localSystem.system) != "riscv64-linux")
              determinate.nixosModules.default
          ++ (cfg.extraModules or [ ])
          ++ extraModules;
        };
    in
    {
      inherit overlays;
      legacyPackages = nixpkgsFor;

      packages = lib.genAttrs systems (
        localSystem:
        let
          pkgs = nixpkgsFor.${localSystem};
        in
        lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
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
        )
        //
          lib.optionalAttrs
            (builtins.elem localSystem [
              "x86_64-linux"
              "aarch64-linux"
            ])
            {
              # `opencode`: boots the sandbox microVM with the current
              # directory shared in as /workspace, runs opencode against llama.cpp on
              # zeta3a (bridged from the host with socat). The guest is a build input
              # of this tool, not a machine, so it's defined inline.
              opencode =
                let
                  guest = inputs.nixpkgs.lib.nixosSystem {
                    system = localSystem;
                    specialArgs = { inherit inputs; };
                    modules = [
                      inputs.microvm.nixosModules.microvm
                      ./microvm/opencode.nix
                    ];
                  };
                in
                pkgs.writeShellApplication {
                  name = "opencode";
                  runtimeInputs = [
                    pkgs.openssh
                    pkgs.coreutils
                    pkgs.socat
                  ];
                  text = ''
                    ws="$PWD"
                    # qemu user-net hostfwd: the guest's sshd is reachable on the
                    # host loopback here (see microvm.forwardPorts in the guest).
                    sshport=2222

                    # Persistent state (store overlay + home/auth) lives here and is
                    # reused between sessions.
                    statedir="''${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
                    mkdir -p "$statedir"

                    # Ephemeral ssh identity, regenerated each run. Only the *public*
                    # key is shared into the VM (via the control dir); the private key
                    # never enters it, so the agent can't use it to reach anything.
                    rundir="$(mktemp -d)"
                    ctldir="$rundir/ctl"
                    mkdir -p "$ctldir"
                    cleanup() {
                      if [ -n "''${vmpid:-}" ]; then kill "$vmpid" 2>/dev/null || true; fi
                      if [ -n "''${socatpid:-}" ]; then kill "$socatpid" 2>/dev/null || true; fi
                      rm -rf "$rundir"
                    }
                    trap cleanup EXIT INT TERM
                    ssh-keygen -t ed25519 -N "" -q -f "$rundir/id" -C opencode
                    cp "$rundir/id.pub" "$ctldir/authorized_keys"

                    servepass="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')"
                    ( umask 077; printf 'OPENCODE_SERVER_USERNAME=opencode\nOPENCODE_SERVER_PASSWORD=%s\n' "$servepass" > "$ctldir/serve-env" )
                    serveurl="http://opencode:$servepass@127.0.0.1:4096"
                    ( umask 077; printf '%s\n' "$serveurl" > "$statedir/serve-url" )

                    # The guest's microvm.extraArgsScript reads these at launch and
                    # attaches them as 9p shares (workspace = CWD, sandboxctl = key).
                    export OPENCODE_SANDBOX_WS="$ws"
                    export OPENCODE_SANDBOX_CTL="$ctldir"

                    socat TCP-LISTEN:5000,bind=127.0.0.1,reuseaddr,fork \
                      TCP:zeta3a.tailde5a8.ts.net:5000 &
                    socatpid=$!

                    # Boot headless; console goes to a log under the state dir.
                    ( cd "$statedir" && exec ${guest.config.microvm.declaredRunner}/bin/microvm-run ) \
                      </dev/null >"$statedir/console.log" 2>&1 &
                    vmpid=$!

                    ssh_opts=(
                      -i "$rundir/id"
                      -p "$sshport"
                      -o StrictHostKeyChecking=no
                      -o UserKnownHostsFile=/dev/null
                      -o LogLevel=ERROR
                      -o ConnectTimeout=2
                    )

                    # Wait for boot + network + key install + sshd.
                    ready=
                    for _ in $(seq 1 120); do
                      if ! kill -0 "$vmpid" 2>/dev/null; then
                        echo "opencode: VM exited during boot; see $statedir/console.log" >&2
                        exit 1
                      fi
                      if ssh "''${ssh_opts[@]}" root@127.0.0.1 true 2>/dev/null; then
                        ready=1
                        break
                      fi
                      sleep 1
                    done
                    if [ -z "$ready" ]; then
                      echo "opencode: timed out waiting for VM ssh; see $statedir/console.log" >&2
                      exit 1
                    fi

                    echo "opencode: remote control at $serveurl (also in $statedir/serve-url)" >&2

                    # Drive opencode over ssh with a real PTY (so the TUI renders
                    # and resizes), in the shared workspace.
                    ssh -t "''${ssh_opts[@]}" root@127.0.0.1 'cd /workspace && exec opencode' || true

                    # Graceful shutdown; cleanup() force-kills if it lingers.
                    ssh "''${ssh_opts[@]}" root@127.0.0.1 'systemctl poweroff' 2>/dev/null || true
                    for _ in $(seq 1 15); do
                      kill -0 "$vmpid" 2>/dev/null || break
                      sleep 1
                    done
                  '';
                };
            }
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
            ./users/${user}/home-${pkgs.stdenv.targetPlatform.parsed.kernel.name}.nix
          ]
          ++ homeManagerModules;
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
            {
              home-manager.sharedModules = homeManagerModules;
              # See the note beside the same line in mkMachine.
              home-manager.extraSpecialArgs = {
                inherit inputs;
              };
            }
            home-manager.darwinModules.default
            stylix.darwinModules.stylix
            determinate.darwinModules.default
            ./system/default.nix
            ./system/darwin.nix
            ./devices/${machine}/default.nix
          ];
        }
      );

      nixosConfigurations = forAllMachines (
        machine: system: mkMachine machine { inherit system; } null [ ]
      );

      # What Hydra builds. Point a jobset at this flake and it fills argama's
      # store, which harmonia then serves to the fleet. The list is
      # cachedMachines above.
      hydraJobs.nixos = lib.genAttrs cachedMachines (
        machine: self.nixosConfigurations.${machine}.config.system.build.toplevel
      );
    };
}
