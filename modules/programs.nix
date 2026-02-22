{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.ross) profile;
in
{
  programs = {
    dconf.enable = true;
    git.enable = true;
    zsh.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    firefox = {
      enable = !pkgs.stdenv.hostPlatform.isRiscV;
      package = pkgs.firefox.overrideAttrs (old: {
        buildCommand = old.buildCommand + ''
          mkdir -p $out/gmp-widevinecdm/system-installed
          ln -s "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm/_platform_specific/linux_arm64/libwidevinecdm.so" $out/gmp-widevinecdm/system-installed/libwidevinecdm.so
          ln -s "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm/manifest.json" $out/gmp-widevinecdm/system-installed/manifest.json
          wrapProgram "$oldExe" \
            --set MOZ_GMP_PATH "$out/gmp-widevinecdm/system-installed"
        '';
      });
    };
  };

  environment.systemPackages =
    with pkgs;
    [
      lm_sensors
      nixpkgs-review
    ]
    ++ lib.optionals (!pkgs.stdenv.hostPlatform.isRiscV64) [
      pkgs.nix-output-monitor
      pkgs.nix-diff
      pkgs.nixfmt-rfc-style
      pkgs.fwupd-efi
      pkgs.android-tools
    ]
    ++ lib.optional (
      stdenv.hostPlatform == stdenv.buildPlatform && profile == "desktop"
    ) papirus-icon-theme;
}
