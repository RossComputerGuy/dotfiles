{ home-manager, pkgs, expr, ... }:
{
  useradd = {
    isNormalUser = true;
    home = "/home/ross";
    description = "Tristan Ross";
    extraGroups = [ "wheel" "docker" "adbusers" "games" ];
  };

  homeManager = {
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
