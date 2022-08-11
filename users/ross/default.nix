{ pkgs, ... }:
let
  nur = import (builtins.fetchTarball {
    url = https://github.com/nix-community/NUR/archive/6600601c83e9404c2dc5a848c4eb65b0beb9f298.zip;
    sha256 = "1xa7cfzjph965a6jlla5s61srflijpz48lzq27m7x0qym5xq9r6q";
  }) {
    inherit pkgs;
  };
in
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
        nur.repos.m15a.vimExtraPlugins.mason-nvim
        colorizer
        cmp-nvim-lua
        cmp-nvim-lsp
        diffview-nvim
        dressing-nvim
        editorconfig-nvim
        fcitx-vim
        gitsigns-nvim
        lspsaga-nvim
        neogit
        nvim-lspconfig
        nvim-cmp
        telescope-nvim
        tokyonight-nvim
        vim-vsnip
        vim-nix
        vim-cursorword
        winshift-nvim
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
