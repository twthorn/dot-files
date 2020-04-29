#!/bin/bash
# git
alias gco='git checkout'
alias gco="git checkout"
alias gdc="git diff --cached"
alias gpom="git push origin master"
alias gmnf="git merge --no-ff"
alias gcm="git commit -m "
alias gdom="git diff origin/master"

# ctags
alias gentagpy="ctags -L <(find . -name '*.py' | cut -c3-) --fields=+iaS --python-kinds=-i --extra=+q -f .git/python.tags"


# ssh
alias fixssh='export $(tmux2 show-environment | grep \^SSH_AUTH_SOCK=)'

# tmux
alias tmux="tmux2"
alias t="tmux attach"
# tpm_folder=~/.tmux/plugins/tpm
# if [[ ! -d $tpm_folder ]]; then
#     echo "Tmux Plugin Manager not found. Installing it now..."
#     mkdir -p $tpm_folder
#     git clone https://github.com/tmux-plugins/tpm $tpm_folder > /dev/null 2>&1
# else
#     git -C $tpm_folder pull > /dev/null 2>&1
# fi
