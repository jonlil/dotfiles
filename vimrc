call plug#begin('~/.vim/plugged')

Plug 'scrooloose/nerdtree'
Plug 'vim-syntastic/syntastic'
Plug 'dikiaap/minimalist'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'editorconfig/editorconfig-vim'
Plug 'digitaltoad/vim-pug'
Plug 'Valloric/YouCompleteMe'
Plug 'marijnh/tern_for_vim'
Plug 'leafgarland/typescript-vim'
Plug 'junegunn/fzf'
Plug 'tpope/vim-fugitive'
Plug 'mattn/emmet-vim'
Plug 'airblade/vim-gitgutter'
Plug 'kannokanno/previm'
Plug 'puppetlabs/puppet-syntax-vim'
Plug 'vim-ruby/vim-ruby'
Plug 'hashivim/vim-terraform'

call plug#end()

filetype plugin indent on
syntax on

set t_Co=256
colorscheme minimalist

highlight diffRemoved ctermfg=red
highlight diffAdded ctermfg=green

set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [],'passive_filetypes': ['puppet'] }
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

let g:airline#extensions#tabline#enabled = 1

let g:airline_theme='dark'
autocmd FileType gitcommit setlocal foldmethod=syntax

set nocompatible
set noswapfile
set nobackup
set ttyfast
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set fileformat=unix  " Unix file format.
set wildmode=longest,list,full  " Bash like command autocomplete
set wildmenu  " Show matches above commandline when pressing TAB.
set more
set nospell
set exrc
set secure
set number
