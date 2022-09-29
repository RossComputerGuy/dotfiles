{ config, pkgs, ... }:
{
  imports = [
    ./home.nix
  ];

  home.file.".config/alacritty/alacritty.yml".source = ./config/alacritty/alacritty.yml;
  home.file.".config/alacritty/alacritty-device.yml".source = ./config/alacritty/alacritty-darwin.yml;
  home.file.".config/nvim/lua/init.lua".source = ./config/nvim/lua/init.lua;
  home.file.".config/sketchybar/plugins".source = ./config/sketchybar/plugins;
  home.file.".config/sketchybar/plugins".recursive = true;
  home.file.".config/sketchybar/sketchybarrc".source = ./config/sketchybar/sketchybarrc;
  home.file.".config/sketchybar/sketchybarrc".executable = true;
  home.file.".config/skhd/skhdrc".source = ./config/skhd/skhdrc;
  home.file.".config/yabai/yabairc".source = ./config/yabai/yabairc;
  home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;

  home.sessionVariables.CPLUS_INCLUDE_PATH = "/usr/local/include/c++/v1:/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/:/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/v1";

  home.packages = with pkgs; [
    noto-fonts
    noto-fonts-emoji
    dejavu_fonts
    migu
    git
    coreutils
  ];

  programs.bash.enableCompletion = true;
}
