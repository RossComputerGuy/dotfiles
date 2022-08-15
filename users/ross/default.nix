{ pkgs, ... }:
{
  users.users.ross = {
    isNormalUser = true;
    home = "/home/ross";
    description = "Tristan Ross";
    extraGroups = [ "wheel" "docker" "adbusers" "games" "input" ];
  };

  home-manager.users.ross = {
    xdg.configFile."nvim/lua/init.lua".source = ./config/nvim/lua/init.lua;
    home.packages = with pkgs; [
      xdg-user-dirs
      jq
      nvimpager
      btop
    ];
    home.sessionVariables = {
      EDITOR = "nvim";
      MANPAGER = "nvimpager";
      PAGER = "nvimpager";
    };
    programs.neovim = {
      enable = true;
      withNodeJs = true;
      withPython3 = true;
      plugins = with pkgs.vimPlugins; [
        packer-nvim
        fcitx-vim
      ];
      extraConfig = ''
        lua require("init")
      '';
    };
    programs.bash = {
      enable = true;
    };
    programs.git = {
      userEmail = "tristan.ross@midstall.com";
      userName = "Tristan Ross";
      extraConfig = {
        core.pager = "nvimpager";
      };
    };
  };
}
