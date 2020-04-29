" automate installation
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
       \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
         autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
         endif

" install plugins
call plug#begin('~/.vim/plugged')
Plug 'metalelf0/supertab'
Plug 'hashivim/vim-terraform'
Plug 'juliosueiras/vim-terraform-completion'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'lifepillar/vim-solarized8'
Plug 'maralla/completor.vim'
Plug 'rodjek/vim-puppet'
Plug 'scrooloose/nerdtree'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-jdaddy'
Plug 'tpope/vim-obsession'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-sleuth'
Plug 'tpope/vim-speeddating'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'w0rp/ale'
call plug#end()

" some default settings
set nocompatible
set backspace=indent,eol,start
set viminfo='20,\"5000,%
set history=5000
set smartcase
set encoding=utf-8

" theme settings
set termguicolors
set background=dark
let g:solarized_use16 = 1
colorscheme solarized8_high

" syntax highlighting
if has("syntax")
  syntax on
endif

" set up persistent undos
if !isdirectory("$HOME/.vim/local/undo")
    silent !mkdir $HOME/.vim/local/undo/ > /dev/null 2>&1
endif
if has('persistent_undo')
  set undofile
  set undodir="$HOME/.vim/local/undo/"
  set undolevels=10000
endif

" plugin settings
" set completor-vim to homedir
let g:completor_python_binary = '/usr/local/bin/python3.6'

let g:ctrlp_match_func = { 'match': 'pymatcher#PyMatch' }
if executable('rg')
  let g:ctrlp_user_command = 'rg %s --smart-case --files --color=never --glob ""'
  let g:ctrlp_use_caching = 0
elseif executable('ag')
  let g:ctrlp_user_command = 'ag %s -i --nocolor --nogroup --hidden
        \ --ignore .git
        \ --ignore .svn
        \ --ignore .hg
        \ --ignore .DS_Store
        \ --ignore "**/*.pyc"
        \ -g ""'
  let g:ctrlp_use_caching = 0
else
  let g:ctrlp_user_command = 'find %s -type f'
  let g:ctrlp_use_caching = 1
endif

let g:ctrlp_cmd = 'CtrlPMixed'
let g:ctrlp_working_path_mode   = 'ra'
let g:ctrlp_custom_ignore       = '\v[\/]\.(git|hg|svn)$'
let g:ctrlp_show_hidden         = 1
let g:ctrlp_max_files           = 1000000
let g:ctrlp_clear_cache_on_exit = 1
let g:ctrlp_match_window        = 'bottom,order:btt,max:20,max:0'
let g:airline_theme                       = 'solarized'
let g:airline#extensions#branch#enabled   = 1
let g:SuperTabDefaultCompletionType = "<c-n>"

" close if only nerd tree is left
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" key bindings
" toggle nerd tree with ctrl-n background
nmap <C-n> :NERDTreeToggle<CR>
" switch background lightness
nmap <silent> <c-b> :let &background = ( &background == "dark"? "light" : "dark" )<CR>
" escape on jk


" additional vim tettings
:imap jk <Esc>
" turn on detection, plugin and indent
filetype plugin indent on
" show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab
" enable line numbers
set number

autocmd vimenter * NERDTree
" Go to previous (last accessed) window.
autocmd VimEnter * wincmd p
" switch panes with vim keys
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

let NERDTreeIgnore = ['\.pyc$']

" completor.vim settings

" Use TAB to complete when typing words, else inserts TABs as usual.  Uses
" dictionary, source files, and completor to find matching words to complete.

" Note: usual completion is on <C-n> but more trouble to press all the time.
" Never type the same word twice and maybe learn a new spellings!
" Use the Linux dictionary when spelling is in doubt.
function! Tab_Or_Complete() abort
  " If completor is already open the `tab` cycles through suggested completions.
  if pumvisible()
    return "\<C-N>"
  " If completor is not open and we are in the middle of typing a word then
  " `tab` opens completor menu.
  elseif col('.')>1 && strpart( getline('.'), col('.')-2, 3 ) =~ '^[[:keyword:][:ident:]]'
    return "\<C-R>=completor#do('complete')\<CR>"
  else
    " If we aren't typing a word and we press `tab` simply do the normal `tab`
    " action.
    return "\<Tab>"
  endif
endfunction

" Use `tab` key to select completions.  Default is arrow keys.
inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" copy to system clipboard
vmap <C-y> "+y

" Use tab to trigger auto completion.  Default suggests completions as you type.
let g:completor_auto_trigger = 0
inoremap <expr> <Tab> Tab_Or_Complete()
