{
  imports = [
    ../../modules
  ];

  nix.settings.auto-optimise-store = true;

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  ross.profile = "desktop";
}
