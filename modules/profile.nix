{ lib, ... }:
{
  options.ross.profile = lib.mkOption {
    description = "Config profile";
    type = lib.types.enum [
      "standard"
      "desktop"
    ];
    default = "standard";
  };

  options.ross.firefoxProfilePath = lib.mkOption {
    description = ''
      Directory name of the Firefox profile, below the Firefox config directory.

      Home Manager writes profiles.ini and points it at this directory. Firefox
      picks a random name for a profile it creates itself, so a machine that
      already has a profile must name it here. If it does not match, Firefox
      opens an empty profile and the bookmarks and history look lost.

      Leave the default on a machine with no Firefox profile yet. Home Manager
      then creates one with this name.
    '';
    type = lib.types.str;
    default = "default";
    example = "8qp9adwe.default";
  };

  options.ross.firefoxConfigPath = lib.mkOption {
    description = ''
      Directory that holds profiles.ini, relative to the home directory.

      Firefox reads ".mozilla/firefox" unless MOZ_LEGACY_HOME is unset in the
      build, in which case it reads the XDG path. Which one a machine uses
      depends on when its profile was made, so it must be set per machine.

      The default matches Home Manager's own default for a home.stateVersion
      below 26.05. Point it at the directory that already has profiles.ini,
      or Firefox opens an empty profile.
    '';
    type = lib.types.str;
    default = ".mozilla/firefox";
    example = ".config/mozilla/firefox";
  };
}
