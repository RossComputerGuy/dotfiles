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
      type = "ibus";
      ibus.engines = with pkgs.ibus-engines; [ mozc ];
    };
  };

  environment = {
    variables = lib.mkIf (config.i18n.inputMethod.enable) {
      GTK_IM_MODULE = "ibus";
      QT_IM_MODULE = "ibus";
      XMODIFIERS = "@im=ibus";
      INPUT_METHOD = "ibus";
      XIM = "ibus";
      XIM_PROGRAM = "ibus";
      SDL_IM_MODULE = "ibus";
      GLFW_IM_MODULE = "ibus";
    };
    sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
