{ lib, ... }:
{
  imports = [
    ../../modules
  ];

  nix.settings.auto-optimise-store = true;

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  # Most machines here are desktops. A headless machine sets the standard
  # profile in its own device file.
  ross.profile = lib.mkDefault "desktop";
}
