{ config, lib, pkgs, ... }:
let
  inherit (lib) mkMerge mkIf;
in
{
  home.packages = with pkgs; [
    jq
    btop
    neofetch
    tree-sitter
    gcc
  ];
  home.stateVersion = "24.05";
  home.sessionVariables.EDITOR = "nvim";
  programs.home-manager.enable = true;
  programs.ghostty = {
    enableZshIntegration = true;
    enable = true;
    settings.theme = "tokyonight";
    themes.tokyonight = {
      background = "#1a1b26";
      foreground = "#c0caf5";
      selection-background = "#283457";
      selection-foreground = "#c0caf5";
      cursor-color = "#c0caf5";
      cursor-text = "#1a1b26";
      palette = [
        "0=#15161e"
        "1=#f7768e"
        "2=#9ece6a"
        "3=#e0af68"
        "4=#7aa2f7"
        "5=#bb9af7"
        "6=#7dcfff"
        "7=#a9b1d6"
        "8=#414868"
        "9=#f7768e"
        "10=#9ece6a"
        "11=#e0af68"
        "12=#7aa2f7"
        "13=#bb9af7"
        "14=#7dcfff"
        "15=#c0caf5"
      ];
    };
  };
  programs.nixvim = {
    enable = pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform;
    colorschemes.tokyonight.enable = true;
    opts = {
      number = true;
      termguicolors = true;
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
    };
    plugins = {
      colorizer.enable = true;
      diffview.enable = true;
      neogit = {
        enable = true;
        settings = {
          kind = "tab";
          auto_refresh = true;
          integrations.diffview = true;
        };
      };
      gitsigns = {
        enable = true;
        settings = {
          current_line_blame = true;
          current_line_blame_opts = {
            virt_text = true;
            virt_text_pos = "eol";
          };
          current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>";
          signcolumn = true;
          numhl = true;
        };
      };
      treesitter = {
        enable = true;
        settings.highlight = {
          enable = true;
          additional_vim_regex_highlighting = true;
        };
      };
      telescope = {
        enable = true;
        enabledExtensions = [
          "media_files"
        ];
      };
    };
    keymaps = [
      {
        action = ":Neogit<CR>";
        key = "<leader>g";
        mode = "n";
      }
      {
        action = "<cmd>Telescope find_files<CR>";
        key = "<leader>ff";
        mode = "n";
      }
      {
        action = "<cmd>Telescope live_grep<CR>";
        key = "<leader>fg";
        mode = "n";
      }
      {
        action = "<cmd>Telescope buffers<CR>";
        key = "<leader>fb";
        mode = "n";
      }
      {
        action = "<cmd>Telescope help_tags<CR>";
        key = "<leader>fb";
        mode = "n";
      }
    ];
    lsp.servers = {
      cssls.enable = !pkgs.stdenv.hostPlatform.isRiscV;
      eslint.enable = !pkgs.stdenv.hostPlatform.isRiscV;
      zls.enable = true;
      html.enable = !pkgs.stdenv.hostPlatform.isRiscV;
      clangd.enable = true;
      jsonls.enable = !pkgs.stdenv.hostPlatform.isRiscV;
    };
    enableMan = !pkgs.stdenv.hostPlatform.isRiscV;
  };
  programs.bash = {
    enable = true;
    enableVteIntegration = true;
  };
  programs.git = {
    enable = true;
    userEmail = "tristan.ross@determinate.systems";
    userName = "Tristan Ross";
    extraConfig = lib.mkIf (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform) {
      core.pager = "nvimpager";
    };
  };
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    enableVteIntegration = true;
    oh-my-zsh = {
      enable = true;
      theme = "tjkirch";
    };
  };
  manual.manpages.enable = false;
  programs.lsd = {
    enable = !pkgs.stdenv.hostPlatform.isRiscV64;
    settings = {
      icons = {
        when = "never";
      };
    };
  };
}
