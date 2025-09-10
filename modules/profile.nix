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
}
