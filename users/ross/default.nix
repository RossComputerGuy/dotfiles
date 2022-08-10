{ pkgs, ... }:
{
  users.users.ross = {
    isNormalUser = true;
    home = "/home/ross";
    description = "Tristan Ross";
    extraGroups = [ "wheel" "docker" "adbusers" "games" ];
  };

  home-manager.users.ross = {
    xdg.configFile."nvim/lua/init.lua".source = ./config/nvim/lua/init.lua;
    home.packages = with pkgs; [
      xdg-user-dirs
      jq
      nvimpager
      btop
    ];
    home.sessionVariables = {
      EDITOR = "nvim";
      MANPAGER = "nvimpager";
      PAGER = "nvimpager";
    };
    programs.neovim = {
      enable = true;
      withNodeJs = true;
      withPython3 = true;
      plugins = with pkgs.vimPlugins; [
        colorizer
        cmp-nvim-lua
        cmp-nvim-lsp
        diffview-nvim
        dressing-nvim
        editorconfig-nvim
        fcitx-vim
        gitsigns-nvim
        lspsaga-nvim
        neogit
        nvim-lspconfig
        nvim-cmp
        telescope-nvim
        tokyonight-nvim
        vim-vsnip
	vim-nix
        vim-cursorword
        winshift-nvim
      ];
      extraConfig = ''
        set number
        colorscheme tokyonight

        noremap <leader>m :WinShift<CR>
        noremap <leader>q :exit<CR>
        noremap <leader>s :w<CR>
        noremap <leader>w :wq<CR>
        noremap <leader>g :Neogit<CR>

        nnoremap <leader>ff <cmd>Telescope find_files<cr>
        nnoremap <leader>fg <cmd>Telescope live_grep<cr>
        nnoremap <leader>fb <cmd>Telescope buffers<cr>
        nnoremap <leader>fh <cmd>Telescope help_tags<cr>

        set completeopt=menu,menuone,noselect
        lua require("init")
      '';
    };
    programs.bash = {
      enable = true;
    };
    programs.git = {
      userEmail = "tristan.ross@midstall.com";
      userName = "Tristan Ross";
      extraConfig = {
        core.pager = "nvimpager";
      };
    };
  };
}
