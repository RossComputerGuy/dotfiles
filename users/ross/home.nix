{ config, lib, pkgs, ... }:
let
  shellAliases =  {
    ls = "lsd";
  };
in
{
  home.packages = with pkgs; [
    jq
    btop
    neofetch
    tree-sitter
  ];
  home.username = if pkgs.targetPlatform.isDarwin then "tristan" else "ross";
  home.homeDirectory = if pkgs.targetPlatform.isDarwin then "/Users/tristan" else "/home/ross";
  home.stateVersion = "22.11";
  home.sessionVariables.EDITOR = "nvim";
  programs.lsd = {
    enable = true;
    settings = {
      icons = {
        when = "never";
      };
    };
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
    enableVteIntegration = true;
    inherit shellAliases;
  };
  programs.git = {
    userEmail = "tristan.ross@midstall.com";
    userName = "Tristan Ross";
    extraConfig = {
      core.pager = "nvimpager";
    };
  };
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    enableSyntaxHighlighting = true;
    enableVteIntegration = true;
    oh-my-zsh = {
      enable = true;
      theme = "tjkirch";
    };
    inherit shellAliases;
  };
}
