#!/bin/bash
# source bash prompt
source ~/.bash_prompt

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# prevent accidental shell exits
export IGNOREEOF=42
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# Append to the history file immediately after each command
shopt -s histappend               # Append history instead of overwriting
PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# git
alias gco='git checkout'
alias gdc="git diff --cached"
alias gp="git pull"
alias gpom="git push origin master"
alias gpom="git push origin HEAD"
alias gmnf="git merge --no-ff"
alias gcm="git commit -m "
alias gdom="git diff origin/master"
alias gs="git status"
alias gap="git add -p"

# git interceptor
alias giti="git_interceptor "
alias gcoi='git_interceptor checkout'
alias gdci="git_interceptor diff --cached"
alias gpi="git_interceptor pull"
alias gpomi="git_interceptor push origin master"
alias gmnfi="git_interceptor merge --no-ff"
alias gcmi="git_interceptor commit -m "
alias gdomi="git_interceptor diff origin/master"
alias gsi="git_interceptor status"
alias gapi="git_interceptor add -p"

gcobu() {
    git checkout -b u/$USER/"$1"
}

gcou() {
    git checkout u/$USER/"$1"
}

gpohu() {
    git push origin HEAD:u/$USER/"$1"
}


gcobui() {
    git_interceptor checkout -b u/$USER/"$1"
}

gcobi() {
    git_interceptor checkout -b "$1"
}

gcoui() {
    git_interceptor checkout u/$USER/"$1"
}

gpohui() {
    git_interceptor push origin HEAD:u/$USER/"$1"
}


CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'

REMOTE_SERVER=""

function git_interceptor() {
    workdir=${PWD:0:18}
    if [[ $workdir == "/Users/$USER/git" ]]; then
        args="$@"
        subdir=${PWD:18}
        remotedir="~$subdir"
        local_rev=$(/usr/bin/git rev-parse --symbolic-full-name HEAD && /usr/bin/git rev-parse HEAD)
        remote_rev=$(ssh $REMOTE_SERVER "cd $remotedir; git rev-parse --symbolic-full-name HEAD && git rev-parse HEAD")
        echo "Matched rev $local_rev"
        echo -e "\n${PURPLE}Remote ($remote_rev):${NC}\n$ git $@"
        OUTPUT=$(ssh -A $REMOTE_SERVER "cd $remotedir; git $@")
        echo -e "${OUTPUT}"
    fi

    echo -e "\n${CYAN}Local ($local_rev):${NC}\n$ git $@"
    /usr/bin/git "$@"
}


# shell
alias ls='ls -G'
export LSCOLORS="fxexcxdxbxegedabagacad"

# ctags
alias gentagpy="ctags -L <(find . -name '*.py' | cut -c3-) --fields=+iaS --python-kinds=-i --extra=+q -f .git/python.tags"

# ssh
alias fixssh='export $(tmux show-environment | grep \^SSH_AUTH_SOCK=)'

# tmux
alias t="tmux attach"
alias tnew='tmux new-session -s "$(basename "$PWD")"'

# python
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

complete -W "\`grep -oE '^[a-zA-Z0-9_.-]+:([^=]|$)' Makefile | sed 's/[^a-zA-Z0-9_.-]*$//'\`" make
