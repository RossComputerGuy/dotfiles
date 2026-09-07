{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  home.file.".config/sketchybar/plugins".source = ./config/sketchybar/plugins;
  home.file.".config/sketchybar/plugins".recursive = true;
  home.file.".config/sketchybar/sketchybarrc".source = ./config/sketchybar/sketchybarrc;
  home.file.".config/sketchybar/sketchybarrc".executable = true;
  home.file.".config/skhd/skhdrc".source = ./config/skhd/skhdrc;
  home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;

  # Stylix defines home.pointerCursor in stylix/hm/cursor.nix, but only when the
  # host platform is Linux. Its x11 target sets home.pointerCursor.x11.enable
  # with no such test. On macOS the two disagree: x11 is on, the cursor name was
  # never defined, and home-manager's xresources module reads that name for
  # Xcursor.theme. The evaluation then stops with "The option
  # `home.pointerCursor.name' was accessed but has no value defined". macOS
  # draws no X11 cursor, and home-manager asserts that home.pointerCursor is
  # Linux only, so turn the whole option off.
  #
  # Set enable, and not the x11 and gtk flags. home-cursor.nix turns itself on
  # when any definition under home.pointerCursor exists at all, so denying those
  # two flags would still count as a definition and keep the block alive. An
  # explicit enable takes priority over that test.
  home.pointerCursor.enable = false;

  home.sessionVariables.CPLUS_INCLUDE_PATH = "/usr/local/include/c++/v1:/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/:/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/v1";
  home.username = "ross";
  home.homeDirectory = mkForce "/Users/ross";
}
