{ lib, pkgs, config, ... }:
let
  inherit (config.ross) profile;
in
{
  time.timeZone = "America/Los_Angeles";

  i18n = {
    defaultLocale = "ja_JP.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" "ja_JP.UTF-8/UTF-8" ];
    inputMethod = lib.mkIf (profile == "desktop") {
      enable = !pkgs.stdenv.hostPlatform.isRiscV64;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = with pkgs; [ fcitx5-mozc ];
      };
    };
  };

  environment = {
    variables = lib.mkIf (config.i18n.inputMethod.enable) {
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      XMODIFIERS = "@im=fcitx";
      INPUT_METHOD = "fcitx";
      XIM = "fcitx";
      XIM_PROGRAM = "fcitx";
      SDL_IM_MODULE = "fcitx";
      GLFW_IM_MODULE = "fcitx";
    };
    sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
