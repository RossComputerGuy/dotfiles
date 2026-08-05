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
  # extraPackages only joins onto opencode's own wrapped PATH, it does not put
  # anything in the profile. These are day to day tools as well (zig, dart,
  # rust-analyzer and friends), so keep them on the real PATH the way the
  # hand-written config did.
  home.packages = lib.mkIf enable oc.lspPackages;

  programs.opencode = {
    inherit enable;
    settings = oc.settings;
    extraPackages = oc.lspPackages;
  };
}
