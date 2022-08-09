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
        editorconfig-nvim
        fcitx-vim
        gitsigns-nvim
        nerdtree
        nerdtree-git-plugin
        tokyonight-nvim
	vim-nix
        vim-cursorword
        winshift-nvim
      ];
      extraConfig = ''
        set number
        colorscheme tokyonight

        autocmd StdinReadPre * let s:std_in=1
        autocmd VimEnter * if argc() == 0 && !exists("s:std_in") && v:this_session == "" | NERDTree | endif
        autocmd BufEnter * if winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree() | quit | endif
        autocmd BufEnter * if bufname("#") =~ "NERD_tree_\d\+" && bufname("%") !~ "NERD_tree_\d\+" && winnr("$") > 1 |
          \ let buf=bufnr() | buffer# | execute "normal! \<C-W>w" | execute "buffer".buf | endif

        noremap <leader>f :NERDTreeFocus<CR>
        noremap <leader>m :WinShift<CR>
        noremap <leader>q :exit<CR>
        noremap <leader>s :w<CR>
        noremap <leader>w :wq<CR>

        lua require("init")
      '';
    };
    programs.bash = {
      enable = true;
    };
    programs.git = {
      enable = true;
      userEmail = "tristan.ross@midstall.com";
      userName = "Tristan Ross";
      extraConfig = {
        core.pager = "nvimpager";
      };
    };
  };
}
