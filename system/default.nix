{ config, lib, pkgs, ... }@args:
{
  imports = [
    ../users/default.nix
  ];

  # flake.nix puts stylix.homeModules.stylix in home-manager.sharedModules for
  # every home-manager path, so stylix must not import it a second time.
  # stylix.base16 is read-only and a second definition is a hard eval error.
  # This file is imported by both mkMachine and darwinConfigurations, which is
  # the only place that covers every configuration that gets a stylix OS module.
  stylix.homeManagerIntegration.autoImport = false;

  nix.settings = {
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

  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    fd
    ripgrep
  ];
}
