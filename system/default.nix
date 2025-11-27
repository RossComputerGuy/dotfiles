{ config, lib, pkgs, ... }@args:
{
  imports = [
    ../users/default.nix
  ];

  nix.settings = {
    auto-optimise-store = true;
    auto-allocate-uids = true;
    experimental-features = [ "nix-command" "flakes" "auto-allocate-uids" "cgroups" ];
    system-features = [ "uid-range" ];
    trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
    trusted-substituters = [ "https://cache.nixos.org" "https://cache.garnix.io" ];
    trusted-users = [ "ross" ];
    # FIXME: making this optional doesn't work correctly
    # needs to be optional since determinate doesn't support riscv64-linux
    # lazy-trees = true;
  };

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    fd
    ripgrep
    clang-tools
    gcc
  ];
}
