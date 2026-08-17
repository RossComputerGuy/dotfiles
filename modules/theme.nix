{
  config,
  options,
  osConfig ? null,
  pkgs,
  inputs,
  ...
}:
let
  # stylix.enable must never read `pkgs`. Stylix defines nixpkgs.overlays from
  # inside its own option tree (stylix/overlays.nix), so building pkgs needs the
  # stylix options and reading pkgs here would need pkgs. That is infinite
  # recursion, and it fires on NixOS and on Home Manager alike. Read the nixpkgs
  # platform options instead, which are plain values.
  #
  # On NixOS `config` holds them. Under Home Manager the NixOS config arrives as
  # `osConfig`, which is a specialArg and therefore safe to read. Standalone
  # Home Manager has no osConfig and always gets a native pkgs from
  # nixpkgsFor.<system>, so there is nothing to guard against there.
  # nix-darwin also supplies osConfig, and it has no nixpkgs.crossSystem, so
  # test for the option rather than assuming osConfig is NixOS shaped.
  nixpkgsCfg =
    if options ? nixpkgs.crossSystem then
      config.nixpkgs
    else if osConfig != null && osConfig.nixpkgs ? crossSystem then
      osConfig.nixpkgs
    else
      null;
  isNative =
    # No crossSystem option in reach means nothing can be cross built here.
    # That covers standalone Home Manager and every nix-darwin configuration.
    nixpkgsCfg == null
    || nixpkgsCfg.crossSystem == null
    # A crossSystem equal to localSystem is a trivial cross, which nixpkgs
    # treats as native. packages.<system>.<machine> always sets crossSystem, so
    # without this check the CI outputs would theme differently from the
    # nixosConfigurations that actually get deployed.
    || (nixpkgsCfg.crossSystem.system or null) == (nixpkgsCfg.localSystem.system or null);

  # The platform the machine runs. crossSystem when there is one, localSystem
  # otherwise. Written as nested tests and not with "or", because crossSystem is
  # null on a native machine and an attribute lookup on null is an error.
  hostSystem =
    if nixpkgsCfg == null then
      null
    else if nixpkgsCfg.crossSystem == null then
      nixpkgsCfg.localSystem.system or null
    else
      nixpkgsCfg.crossSystem.system or null;

  # Stylix themes GTK by building adw-gtk3, which needs dart-sass to build, and
  # nixpkgs has no riscv64 dart-sass. So a native riscv64 evaluation stops at
  # "Refusing to evaluate package 'dart-sass'" before it reaches anything else.
  # This takes nothing away from jegan or mu-gundam: both are built through the
  # cross outputs under packages, where isNative is already false and stylix is
  # already off.
  isRiscV = hostSystem == "riscv64-linux";
in
{
  # One palette for every themed application. Stylix replaces the per-application
  # themes that used to live in home.nix and home-linux.nix.
  stylix = {
    # Stylix pulls in GTK themes, fonts and icon sets. Keep it off when we cross
    # compile, which matches how gtk, fontconfig and nixvim are already gated.
    enable = isNative && !isRiscV;
    polarity = "dark";
    # A source path and not a package. Stylix reads this file while it
    # evaluates, so naming a file inside pkgs.base16-schemes made Nix build that
    # package for the machine's own platform before it could evaluate the
    # machine at all. A riscv64 machine could then be evaluated on riscv64
    # hardware alone. See the base16-schemes input in flake.nix.
    base16Scheme = "${inputs.base16-schemes}/base16/tokyo-night-dark.yaml";
    # The gnome target enables itself on Linux and reads this. Because
    # base16Scheme is set, the palette generator never runs.
    image = ../users/ross/pictures/wallpaper.jpg;

    cursor = {
      package = pkgs.shuba-cursors;
      name = "Shuba";
      size = 24;
    };

    fonts = {
      sansSerif = {
        package = pkgs.migu;
        name = "Migu 1P";
      };
      serif = {
        package = pkgs.migu;
        name = "Migu 1P";
      };
      monospace = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans Mono";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
  };
}
