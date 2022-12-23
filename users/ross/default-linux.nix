{ ... }: {
  name = "ross";
  home = "/home/ross";
  extraGroups = [ "wheel" "docker" "adbusers" "games" "input" "video" ];
  isNormalUser = true;
}
