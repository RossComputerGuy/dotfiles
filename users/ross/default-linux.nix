{ config, lib, ... }: {
  name = "ross";
  home = "/home/ross";
  extraGroups = [ "wheel" "docker" "games" "input" "video" "dialout" ]
    ++ lib.optional config.programs.adb.enable "adbusers";
  isNormalUser = true;
}
