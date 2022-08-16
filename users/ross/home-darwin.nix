{ config, pkgs, ... }:
{
  imports = [
    ./home.nix
  ];

  home.file.".config/alacritty/alacritty.yml".source = ./config/alacritty/alacritty.yml;
  home.file.".config/alacritty/alacritty-device.yml".source = ./config/alacritty/alacritty-darwin.yml;
  home.file.".config/nvim/lua/init.lua".source = ./config/nvim/lua/init.lua;
  home.file.".config/skhd/skhdrc".source = ./config/skhd/skhdrc;
  home.file.".config/yabai/yabairc".source = ./config/yabai/yabairc;
  home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;
}
