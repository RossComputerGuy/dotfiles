{
  pkgs,
  lib,
  baseURL,
}:
let
  inherit (lib) getExe getExe';
  vscodeLs = pkgs.vscode-langservers-extracted;
  catalog = import ./opencode-models.nix;
  mcpServers = import ./mcp-servers.nix { inherit pkgs lib; };
  model = name: {
    inherit name;
    tools = true;
  };
  mcpEnv = name: lib.optionalAttrs (name == "memory") {
    MEMORY_FILE_PATH = "{env:HOME}/.opencode-memory.json";
  };
  mcpEntry = name: s: {
    type = "local";
    command = s.command;
    enabled = true;
    environment = mcpEnv name;
  };
in
{
  lspPackages = with pkgs; [
    nixd
    clang-tools
    rust-analyzer
    zls
    zig
    typescript
    typescript-language-server
    vscode-langservers-extracted
    dart
  ];

  settings = {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;

    lsp = {
      css = {
        command = [
          (getExe' vscodeLs "vscode-css-language-server")
          "--stdio"
        ];
        extensions = [
          ".css"
          ".scss"
          ".less"
        ];
      };
      html = {
        command = [
          (getExe' vscodeLs "vscode-html-language-server")
          "--stdio"
        ];
        extensions = [ ".html" ];
      };
      json = {
        command = [
          (getExe' vscodeLs "vscode-json-language-server")
          "--stdio"
        ];
        extensions = [
          ".json"
          ".jsonc"
        ];
      };
      dart = {
        command = [
          (getExe pkgs.dart)
          "language-server"
          "--protocol=lsp"
        ];
        extensions = [ ".dart" ];
      };
    };

    provider.llamacpp = {
      npm = "@ai-sdk/openai-compatible";
      name = "llama.cpp (zeta3a)";
      options = {
        inherit baseURL;
        apiKey = "local";
      };
      models = lib.mapAttrs (_: m: model m.display) catalog;
    };

    mcp = lib.mapAttrs mcpEntry mcpServers;
  };
}
