{ config, lib, pkgs, ... }:
let
  inherit (lib) mkMerge mkIf;
in
{
  imports = [
    ./opencode.nix
  ];

  home.packages = with pkgs; [
    jq
    btop
    fastfetch
    tree-sitter
    gcc
  ];
  home.stateVersion = "24.05";
  # On unstable nixpkgs, home-manager's release string lags nixpkgs; the skew is
  # expected and harmless.
  home.enableNixpkgsReleaseCheck = false;
  home.sessionVariables.EDITOR = "nvim";
  programs.home-manager.enable = true;
  programs.ghostty = {
    enableZshIntegration = true;
    enable = pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform && !pkgs.stdenv.hostPlatform.isRiscV64;
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
    # Use the same nixpkgs as the rest of the system on purpose (it follows our
    # flake input), and quiet the version-skew check since we track unstable.
    nixpkgs.source = pkgs.path;
    version.enableNixpkgsReleaseCheck = false;
    colorschemes.tokyonight.enable = true;

    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    opts = {
      number = true;
      termguicolors = true;
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      signcolumn = "yes";
      cursorline = true;
      scrolloff = 8;
      undofile = true;
    };

    # Formatters invoked by conform need to be on neovim's PATH.
    extraPackages = with pkgs; [
      nixfmt
      clang-tools
      rustfmt
      prettierd
    ];

    plugins = {
      web-devicons.enable = true;
      colorizer.enable = true;
      diffview.enable = true;
      nvim-autopairs.enable = true;
      comment.enable = true;
      todo-comments.enable = true;
      which-key.enable = true;
      indent-blankline.enable = true;
      treesitter-context.enable = true;
      friendly-snippets.enable = true;

      lualine = {
        enable = true;
        settings.options.theme = "tokyonight";
      };

      bufferline.enable = true;

      alpha = {
        enable = true;
        theme = "startify";
      };

      notify.enable = true;
      noice.enable = true;

      neo-tree = {
        enable = true;
        settings.close_if_last_window = true;
      };

      trouble.enable = true;

      blink-cmp = {
        enable = true;
        settings = {
          keymap = {
            preset = "enter";
            "<Tab>" = [ "select_next" "fallback" ];
            "<S-Tab>" = [ "select_prev" "fallback" ];
          };
          sources.default = [ "lsp" "path" "snippets" "buffer" ];
          appearance.nerd_font_variant = "mono";
          completion.documentation.auto_show = true;
          signature.enabled = true;
        };
      };

      conform-nvim = {
        enable = true;
        settings = {
          formatters_by_ft = {
            nix = [ "nixfmt" ];
            c = [ "clang_format" ];
            cpp = [ "clang_format" ];
            rust = [ "rustfmt" ];
            astro = [ "prettierd" ];
            css = [ "prettierd" ];
            html = [ "prettierd" ];
            json = [ "prettierd" ];
            javascript = [ "prettierd" ];
            typescript = [ "prettierd" ];
          };
          # Fall back to the LSP formatter (zig/dart) when no formatter is listed.
          format_on_save = {
            lsp_format = "fallback";
            timeout_ms = 2000;
          };
        };
      };

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
      treesitter-textobjects = {
        enable = true;
        settings.select = {
          enable = true;
          lookahead = true;
          keymaps = {
            "af" = "@function.outer";
            "if" = "@function.inner";
            "ac" = "@class.outer";
            "ic" = "@class.inner";
            "aa" = "@parameter.outer";
            "ia" = "@parameter.inner";
          };
        };
      };
      telescope = {
        enable = true;
        extensions.ui-select.enable = true;
      };
    };

    keymaps = [
      {
        action = "<cmd>Neogit<CR>";
        key = "<leader>g";
        mode = "n";
        options.desc = "Neogit";
      }
      {
        action = "<cmd>Gitsigns blame_line<CR>";
        key = "<leader>gb";
        mode = "n";
        options.desc = "Git blame line (popup)";
      }
      {
        action = "<cmd>Gitsigns blame<CR>";
        key = "<leader>gB";
        mode = "n";
        options.desc = "Git blame file";
      }
      {
        action = "<cmd>Neotree toggle<CR>";
        key = "<leader>e";
        mode = "n";
        options.desc = "Toggle file tree";
      }
      {
        action = "<cmd>Telescope find_files<CR>";
        key = "<leader>ff";
        mode = "n";
        options.desc = "Find files";
      }
      {
        action = "<cmd>Telescope live_grep<CR>";
        key = "<leader>fg";
        mode = "n";
        options.desc = "Live grep";
      }
      {
        action = "<cmd>Telescope buffers<CR>";
        key = "<leader>fb";
        mode = "n";
        options.desc = "Buffers";
      }
      {
        action = "<cmd>Telescope help_tags<CR>";
        key = "<leader>fh";
        mode = "n";
        options.desc = "Help tags";
      }
      {
        action = "<cmd>Trouble diagnostics toggle<CR>";
        key = "<leader>xx";
        mode = "n";
        options.desc = "Diagnostics (Trouble)";
      }
      {
        action = "<cmd>BufferLineCycleNext<CR>";
        key = "<S-l>";
        mode = "n";
        options.desc = "Next buffer";
      }
      {
        action = "<cmd>BufferLineCyclePrev<CR>";
        key = "<S-h>";
        mode = "n";
        options.desc = "Previous buffer";
      }
    ];

    # Buffer-local LSP keymaps, wired on attach so they work with every server.
    autoCmd = [
      {
        event = [ "LspAttach" ];
        callback.__raw = ''
          function(ev)
            local opts = { buffer = ev.buf, silent = true }
            local map = vim.keymap.set
            map("n", "gd", vim.lsp.buf.definition, opts)
            map("n", "gD", vim.lsp.buf.declaration, opts)
            map("n", "gi", vim.lsp.buf.implementation, opts)
            map("n", "gr", vim.lsp.buf.references, opts)
            map("n", "gy", vim.lsp.buf.type_definition, opts)
            map("n", "K", vim.lsp.buf.hover, opts)
            map("n", "<leader>rn", vim.lsp.buf.rename, opts)
            map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
            map("n", "<leader>cd", vim.diagnostic.open_float, opts)
            map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, opts)
            map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, opts)
            map("n", "<leader>cf", function() require("conform").format({ lsp_format = "fallback" }) end, opts)
          end
        '';
      }
    ];

    lsp.servers = {
      cssls.enable = !pkgs.stdenv.hostPlatform.isRiscV;
      eslint.enable = !pkgs.stdenv.hostPlatform.isRiscV;
      zls.enable = true;
      html.enable = !pkgs.stdenv.hostPlatform.isRiscV;
      clangd.enable = true;
      jsonls.enable = !pkgs.stdenv.hostPlatform.isRiscV;
      nixd.enable = !pkgs.stdenv.hostPlatform.isRiscV;
      rust_analyzer.enable = !pkgs.stdenv.hostPlatform.isRiscV;
      dartls.enable = !pkgs.stdenv.hostPlatform.isRiscV;
      astro.enable = !pkgs.stdenv.hostPlatform.isRiscV;
    };
    enableMan = !pkgs.stdenv.hostPlatform.isRiscV;
  };
  programs.bash = {
    enable = true;
    enableVteIntegration = true;
  };
  programs.git = {
    enable = true;
    settings = {
      user = {
        email = "tristan.ross@determinate.systems";
        name = "Tristan Ross";
      };
      core.pager = lib.mkIf (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform) "nvimpager";
    };
    signing.format = "openpgp";
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
    enable = !pkgs.stdenv.hostPlatform.isRiscV64 && pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform;
    settings = {
      icons = {
        when = "never";
      };
    };
  };
}
