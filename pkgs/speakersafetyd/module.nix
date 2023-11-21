{ pkgs, lib, config, ... }:
with lib;
with builtins;
let
  self = config.services.speakersafetyd;
in
{
  options.services.speakersafetyd = {
		enable = mkEnableOption "Enable speakersafetyd";

		package = mkOption {
			type = types.package;
			default = pkgs.speakersafetyd;
			description = "The name of the speakersafetyd package";
		};
	};

	config = mkIf config.services.speakersafetyd.enable {
		nixpkgs.overlays = [
			(self: super: {
				speakersafetyd = super.callPackage ./package.nix {};
			})
		];

		systemd.services.speakersafetyd = {
			enable = true;
			script = ''
				${self.package}/bin/speakersafetyd \
					-c ${self.package}/share/speakersafetyd/ \
					-b /var/lib/speakersafetyd/blackbox \
					-m 7
			'';
			wantedBy = [ "multi-user.target" ];
			description = "Speaker Protection Daemon";
			serviceConfig = {
				UMask = "0066";
				Restart = "on-failure";
				RestartSec = 1;
				StartLimitBurst = 10;
			};
		};

		systemd.tmpfiles.rules = [
			"z /var/lib/speakersafetyd 0700 root root -"
		];

		services.udev.packages = [ self.package ];
	};
}
