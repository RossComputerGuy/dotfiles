{ config, lib, pkgs, ... }:
let
  inherit (lib) mkMerge mkIf;

  shellAliases = lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == pkgs.stdenv.buildPlatform.system) {
    ls = "lsd";
  };
in
{
  home.packages = with pkgs; [
    jq
    btop
    neofetch
    tree-sitter
    gcc
    nodePackages.dockerfile-language-server-nodejs
  ];
  home.stateVersion = "24.05";
  home.sessionVariables.EDITOR = "nvim";
  programs.home-manager.enable = true;
  programs.neovim = {
    enable = true;
    withNodeJs = true;
    withPython3 = true;
    plugins = with pkgs.vimPlugins; [
      packer-nvim
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
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    enableVteIntegration = true;
    oh-my-zsh = {
      enable = true;
      theme = "tjkirch";
    };
    inherit shellAliases;
  };
  manual.manpages.enable = false;
  programs.lsd = mkIf (shellAliases ? "ls") {
    enable = true;
    settings = {
      icons = {
        when = "never";
      };
    };
  };
}
