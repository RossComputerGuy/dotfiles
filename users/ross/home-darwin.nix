{ config, lib, pkgs, ... }:
with lib;
{
  home.file.".config/alacritty/alacritty.toml".source = ./config/alacritty/alacritty.toml;
  home.file.".config/alacritty/alacritty-device.toml".source = ./config/alacritty/alacritty-darwin.toml;
  home.file.".config/sketchybar/plugins".source = ./config/sketchybar/plugins;
  home.file.".config/sketchybar/plugins".recursive = true;
  home.file.".config/sketchybar/sketchybarrc".source = ./config/sketchybar/sketchybarrc;
  home.file.".config/sketchybar/sketchybarrc".executable = true;
  home.file.".config/skhd/skhdrc".source = ./config/skhd/skhdrc;
  home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;

  home.sessionVariables.CPLUS_INCLUDE_PATH = "/usr/local/include/c++/v1:/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/:/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/v1";
  home.username = "ross";
  home.homeDirectory = mkForce "/Users/ross";
}
