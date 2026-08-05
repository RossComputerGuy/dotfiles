{ ... }:
{
  time.timeZone = "America/Los_Angeles";

  i18n = {
    defaultLocale = "ja_JP.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" "ja_JP.UTF-8/UTF-8" ];
  };

  # fcitx5 moved to home-manager, in users/ross/home-linux.nix, so that stylix
  # can theme it. Home Manager sets the input method session variables itself.
  # With waylandFrontend it deliberately leaves GTK_IM_MODULE and QT_IM_MODULE
  # unset, because native Wayland clients use text-input instead.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
