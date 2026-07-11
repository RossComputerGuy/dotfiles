{
  config,
  lib,
  pkgs,
  ...
}:
let
  native = pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform;
  enable = native && !pkgs.stdenv.hostPlatform.isRiscV64;
  oc = import ./opencode-config.nix {
    inherit pkgs lib;
    baseURL = "http://zeta3a.tailde5a8.ts.net:5000/v1";
  };
in
{
  home.packages = lib.mkIf enable ([ pkgs.opencode ] ++ oc.lspPackages);
  xdg.configFile."opencode/opencode.json" = lib.mkIf enable {
    text = builtins.toJSON oc.settings;
  };
}
