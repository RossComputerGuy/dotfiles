{ pkgs, ... }:
{
  users.users.ross = {
    isNormalUser = true;
    home = "/home/ross";
    description = "Tristan Ross";
    extraGroups = [ "wheel" "docker" "adbusers" "games" "input" ];
  };

  home-manager.users.ross = builtins.concatMap (import ./home.nix {}; import ./home-linux.nix {};);
}
