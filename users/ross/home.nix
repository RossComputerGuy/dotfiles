{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    jq
    btop
    neofetch
  ];
  home.sessionVariables.EDITOR = "nvim";
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
  };
}
