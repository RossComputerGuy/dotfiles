{ config, lib, pkgs, ... }:
let
  inherit (lib) mkMerge mkIf;
in
{
  home.packages = with pkgs; [
    jq
    btop
    neofetch
    tree-sitter
    gcc
  ] ++ lib.optional (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform) pkgs.nodePackages.dockerfile-language-server-nodejs;
  home.stateVersion = "24.05";
  home.sessionVariables.EDITOR = "nvim";
  programs.home-manager.enable = true;
  programs.neovim = {
    enable = pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform;
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
  };
  programs.git = {
    userEmail = "tristan.ross@midstall.com";
    userName = "Tristan Ross";
    extraConfig = lib.mkIf (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform) {
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
  };
  manual.manpages.enable = false;
  programs.lsd = {
    enable = true;
    settings = {
      icons = {
        when = "never";
      };
    };
  };
}
