{ pkgs, lib }:
let
  inherit (lib) getExe getExe';
in
{
  memory = {
    scope = "global";
    command = [ (getExe' pkgs.mcp-server-memory "mcp-server-memory") ];
  };

  fetch = {
    scope = "global";
    command = [ (getExe' pkgs.mcp-server-fetch "mcp-server-fetch") ];
  };

  time = {
    scope = "global";
    command = [ (getExe' pkgs.mcp-server-time "mcp-server-time") ];
  };

  sequential-thinking = {
    scope = "global";
    command = [ (getExe' pkgs.mcp-server-sequential-thinking "mcp-server-sequential-thinking") ];
  };

  context7 = {
    scope = "global";
    command = [ (getExe' pkgs.context7-mcp "context7-mcp") ];
  };

  nixos = {
    scope = "global";
    command = [ (getExe' pkgs.mcp-nixos "mcp-nixos") ];
  };

  lsp = {
    scope = "workspace";
    command = [
      (getExe' pkgs.mcp-language-server "mcp-language-server")
      "-workspace"
      "."
      "-lsp"
      (getExe pkgs.nixd)
    ];
  };
}
