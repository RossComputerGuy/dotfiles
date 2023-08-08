{ config, pkgs, lib, ... }:
{
  homebrew.enable = true;

  programs.gnupg.agent.enable = true;
}
