{ config, lib, pkgs, ... }:
{
  imports = [
    ../../system/linux/desktop.nix
    ../../pkgs/speakersafetyd/module.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  virtualisation.waydroid.enable = true;

  boot.kernelPackages =
    let
			kernelPackages = pkgs.linux-asahi.override {
				_kernelPatches = config.boot.kernelPatches;
				_4KBuild = config.hardware.asahi.use4KPages;
				withRust = config.hardware.asahi.withRust;
			};
			kernel = kernelPackages.kernel.overrideAttrs (old: {
        src = pkgs.fetchFromGitHub {
          owner = "AsahiLinux";
          repo = "linux";
          rev = "asahi-6.5-27";
          hash = "sha256-6ApeS1Pp8L+bZ0BusJ5j97awV4HF9g4CXZJKe1/lZLE=";
        };
				version = "asahi-6-latest";
				unpackPhase = ''
					cp -r $(realpath $src)/. .
					chmod -R u+w .
				'';
			});
		in
			lib.mkForce (pkgs.linuxPackagesFor kernel);

  services.speakersafetyd = {
    enable = true;
    package = pkgs.callPackage ../../pkgs/speakersafetyd {};
  };

  services.pipewire =
		let
			bankstown = pkgs.callPackage ../../pkgs/lsp-plugins/bankstown.nix { };

			lv2Plugins = with pkgs; [
				lsp-plugins
				bankstown
			];

			withPlugins = bin: pkg:
				pkg.overrideAttrs (old: {
					nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.makeWrapper ];
					postInstall = ''
						# Taken from pkgs/applications/audio/pulseeffects/default.nix.
						wrapProgram $out/bin/${bin} \
							--prefix LV2_PATH : ${lib.makeSearchPath "lib/lv2" lv2Plugins}
					'';
				});
		in
		{
			package =
				let
					pipewire = pkgs.pipewire;
				in
					assert lib.assertMsg
						(lib.versionAtLeast pipewire.version "0.3.84")
						("Pipewire version is too old, need at least 0.3.84, got ${pipewire.version}");
					pipewire;

			wireplumber.package =
				assert lib.assertMsg
					(lib.versionAtLeast pkgs.wireplumber.version "0.4.15")
					("Wireplumber version is too old, need at least 0.4.15, got ${pkgs.wireplumber.version}");
				withPlugins "wireplumber" (pkgs.wireplumber.overrideAttrs (old: {
				}));
		};

  environment.etc =
		with lib;
		with builtins;
		let
			asahi-audio = pkgs.callPackage ./asahi-audio.nix { };
			paths = [
				"pipewire/pipewire.conf.d/99-asahi.conf"
				"pipewire/pipewire-pulse.conf.d/99-asahi.conf"
				"wireplumber/main.lua.d/85-asahi.lua"
				"wireplumber/policy.lua.d/85-asahi-policy.lua"
				"wireplumber/scripts/policy-asahi.lua"
			];
		in
			listToAttrs
				(map
					(path: {
						name = "${path}";
						value = {
							source = "${asahi-audio}/share/${path}";
							target = "${path}";
							mode = "0444";
						};
					})
					paths);

	system.replaceRuntimeDependencies = [
		{
      original = pkgs.alsa-ucm-conf;
      replacement = pkgs.callPackage ./alsa-ucm-conf-asahi.nix {
        inherit (pkgs) alsa-ucm-conf;
      };
		}
		{
			original = pkgs.alsa-lib;
			replacement = pkgs.alsa-lib-asahi;
		}
	];

  boot.binfmt = {
    emulatedSystems = [
      "x86_64-linux"
      "i386-linux"
    ];
  };

  boot.kernelPatches = [{
    name = "waydroid";
    patch = null;
    extraConfig = ''
      ANDROID_BINDER_IPC y
      ANDROID_BINDERFS y
      ANDROID_BINDER_DEVICES binder,hwbinder,vndbinder
      ASHMEM y
      ANDROID_BINDERFS y
      ANDROID_BINDER_IPC y
    '';
  }];

  programs.firefox.enable = true;

  hardware.bluetooth.enable = true;
  networking = {
    hostName = "hizack-b";
    wireless = {
      enable = false;
      iwd.enable = true;
    };
    networkmanager.wifi.backend = "iwd";
  };

  hardware.asahi = {
    extractPeripheralFirmware = true;
    peripheralFirmwareDirectory = ./firmware;
    useExperimentalGPUDriver = true;
    addEdgeKernelConfig = true;
  };

  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0
  '';

  fileSystems."/" = {
    device = "/dev/nvme0n1p5";
    fsType = "ext4";
  };

  # Users
  home-manager.users.ross.xdg.configFile."eww/device.yuck".source = ./config/eww/device.yuck;
  home-manager.users.ross.xdg.configFile."sway/config.d/device.conf".source = ./config/sway/config.d/device.conf;
}
