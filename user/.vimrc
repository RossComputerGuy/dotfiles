set ai
set expandtab
set tabstop=2
set softtabstop=2
set shiftwidth=2
set number
set noshowmode
set laststatus=2
set paste

let g:NERDTreeWinPos = 'left'
let g:NERDTreeShowHidden = 1
let g:NERDTreeMinimalUI = 1
let g:NERDTreeDirArrowExpandable = ''
let g:NERDTreeDirArrowCollapsible = ''

let g:lightline = {
  \ 'colorscheme': 'tokyonight',
  \ 'active': {
  \   'left': [['mode']],
  \   'right': [['percent', 'lineinfo']],
  \ }
  \ }

let g:tokyonight_style = 'night'
let g:tokyonight_enable_italic = 1
let g:tokyonight_transparent_background = 1

call plug#begin('~/.vim/plugged')
	Plug 'scrooloose/nerdtree'
	Plug 'terryma/vim-multiple-cursors'
  Plug 'itchyny/lightline.vim'
  Plug 'ghifarit53/tokyonight-vim'
call plug#end()

map <F1> :NERDTreeToggle<CR>
map <F2> :NERDTreeFind<CR>

autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") && v:this_session == "" | NERDTree | endif

syntax on
colorscheme tokyonight
