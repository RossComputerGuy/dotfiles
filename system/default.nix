{ config, pkgs, ... }@args:
{
  imports = [
    ../users/default.nix
  ];

  nixpkgs.config.allowUnfree = true;

  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    sumneko-lua-language-server
    rnix-lsp
    fd
    ripgrep
    cachix
    clang-tools
    gcc
  ];
}
