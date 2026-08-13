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
    trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" "argama-1:D/CZ1iVEV+tjTUcYklCVGGhOkxHtx6M8B5j6hBYuSEk=" ];
    trusted-substituters = [ "https://cache.nixos.org" "https://cache.garnix.io" "http://cache.argama.nix" ];
    # Only argama goes here. This option adds to the default rather than
    # replacing it, so cache.nixos.org stays without being named again.
    #
    # argama serves plain HTTP because the Nix daemon needs a certificate
    # authority before it starts, and OpenBao hands out argama's authority long
    # after that. The signature on each store path is what carries the trust,
    # and the key above checks it, so the transport does not have to.
    #
    # The name resolves through argama's DNS alone. Until the router hands out
    # 192.168.1.163, or Tailscale sends the .nix zone to 100.94.55.6, a client
    # away from that DNS logs a warning for each query and then carries on.
    substituters = [ "http://cache.argama.nix" ];
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
