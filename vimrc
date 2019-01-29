call plug#begin('~/.vim/plugged')

Plug 'scrooloose/nerdtree'
Plug 'vim-syntastic/syntastic'
Plug 'dikiaap/minimalist'
Plug 'lifepillar/vim-solarized8'
Plug 'kristijanhusak/vim-hybrid-material'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'editorconfig/editorconfig-vim'
Plug 'digitaltoad/vim-pug'
Plug 'marijnh/tern_for_vim'
Plug 'leafgarland/typescript-vim'
Plug 'junegunn/fzf'
Plug 'tpope/vim-fugitive'
Plug 'mattn/emmet-vim'
Plug 'airblade/vim-gitgutter'
Plug 'kannokanno/previm'
Plug 'rodjek/vim-puppet'
Plug 'vim-ruby/vim-ruby'
Plug 'hashivim/vim-terraform'
Plug 'Valloric/YouCompleteMe'

Plug 'majutsushi/tagbar'
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
Plug 'rust-lang/rust.vim'
Plug 'vim-scripts/groovy.vim'
Plug 'asciidoc/vim-asciidoc'
Plug 'ngmy/vim-rubocop'
Plug 'nvie/vim-flake8'

call plug#end()

filetype plugin indent on
syntax on

set t_Co=256
set background=dark
colorscheme hybrid_material

highlight diffRemoved ctermfg=red
highlight diffAdded ctermfg=green
highlight clear SpellBad
highlight SpellBad cterm=underline

set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let NERDTreeShowHidden=1
let g:syntastic_mode_map = { 'mode': 'passive', 'active_filetypes': [],'passive_filetypes': ['puppet'] }
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:UltiSnipsJumpBackwardTrigger="<c-z>"

" ---------------------------------- "
" Configure YouCompleteMe
" ---------------------------------- "

let g:ycm_collect_identifiers_from_tags_files = 1 " Let YCM read tags from Ctags file
let g:ycm_use_ultisnips_completer = 1 " Default 1, just ensure
let g:ycm_seed_identifiers_with_syntax = 1 " Completion for programming language's keyword
let g:ycm_complete_in_comments = 1 " Completion in comments
let g:ycm_complete_in_strings = 1 " Completion in string

let g:ycm_key_list_select_completion = ['<C-j>', '<Down>']
let g:ycm_key_list_previous_completion = ['<C-k>', '<Up>']

" Goto definition with F3
map <F3> :YcmCompleter GoTo<CR>

" ---------------------------------- "
"  Rust
" ---------------------------------- "
let g:rustfmt_autosave = 1
let g:racer_cmd="/Users/jonas/.cargo/bin/racer"

let g:airline#extensions#tabline#enabled = 1

let g:airline_theme='dark'
let g:syntastic_sh_shellcheck_args="-x"
autocmd FileType gitcommit setlocal foldmethod=syntax

au BufRead,BufNewFile *.nginx set ft=nginx
au BufRead,BufNewFile *.ssh/config.d/* set ft=sshconfig
au BufRead,BufNewFile */etc/nginx/* set ft=nginx
au BufRead,BufNewFile */usr/local/nginx/conf/* set ft=nginx
au BufRead,BufNewFile nginx.conf set ft=nginx
au BufRead,BufNewFile Jenkinsfile set ft=groovy

au FileType sh setl sts=2 et
au FileType ruby setl ts=2 sts=2 sw=2 et
au FileType terraform setl ts=2 sts=2 sw=2 et
au FileType yaml setl ts=2 sts=2 sw=2 et

set tabstop=4       " The width of a TAB is set to 4.
                    " Still it is a \t. It is just that
                    " Vim will interpret it to be having
                    " a width of 4.

set shiftwidth=4    " Indents will have a width of 4

set softtabstop=4   " Sets the number of columns for a TAB

set expandtab       " Expand TABs to spaces

set nocompatible
set noswapfile
set nobackup
set ttyfast
set tabstop=4
set fileformat=unix  " Unix file format.
set wildmode=longest,list,full  " Bash like command autocomplete
set wildmenu  " Show matches above commandline when pressing TAB.
set more

" ---------------------------------- "
" Spelling
" ---------------------------------- "
set spell spelllang=en_us,sv

set exrc
set secure
set number
set list
set listchars=eol:$,tab:>-,trail:~,extends:>,precedes:<
set backspace=indent,eol,start

cabbrev w!! w !sudo tee % >/dev/null

nmap <F8> :TagbarToggle<CR>
