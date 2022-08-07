{ pkgs, ... }:
{
  users.users.ross = {
    isNormalUser = true;
    home = "/home/ross";
    description = "Tristan Ross";
    extraGroups = [ "wheel" "docker" "adbusers" "games" ];
  };

  home-manager.users.ross = {
    home.packages = with pkgs; [
      xdg-user-dirs
      jq
    ];
    programs.git = {
      userEmail = "tristan.ross@midstall.com";
      userName = "Tristan Ross";
    };
  };
}
