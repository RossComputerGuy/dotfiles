{ pkgs, ... }:
{
  users.users.ross = {
    isNormalUser = true;
    home = "/home/ross";
    description = "Tristan Ross";
    extraGroups = [ "wheel" "docker" "adbusers" "games" ];
  };

  home-manager.users.ross = {
    xdg.configFile."nvim/lua/init.lua".source = ./config/nvim/lua/init.lua;
    home.packages = with pkgs; [
      xdg-user-dirs
      jq
    ];
    programs.neovim = {
      enable = true;
      withNodeJs = true;
      withPython3 = true;
      plugins = with pkgs.vimPlugins; [
        colorizer
        editorconfig-nvim
        fcitx-vim
        gitsigns-nvim
        nerdtree
        nerdtree-git-plugin
        tokyonight-nvim
	vim-nix
        vim-cursorword
        winshift-nvim
      ];
      extraConfig = ''
        set number

        lua require("init")
      '';
    };
    programs.git = {
      enable = true;
      userEmail = "tristan.ross@midstall.com";
      userName = "Tristan Ross";
    };
  };
}
