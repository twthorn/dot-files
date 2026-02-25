#!/bin/bash
# source bash prompt
source ~/.bash_prompt

# Build PATH - use $HOME for portability across macOS/Linux
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# Homebrew (macOS)
[[ -d /opt/homebrew/bin ]] && export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
# Go
[[ -d /usr/local/go/bin ]] && export PATH="/usr/local/go/bin:$PATH"
[[ -d "$HOME/go/bin" ]] && export PATH="$HOME/go/bin:$PATH"
# goenv
export GOENV_ROOT="$HOME/.goenv"
[[ -d "$GOENV_ROOT/bin" ]] && export PATH="$GOENV_ROOT/bin:$PATH"
command -v goenv >/dev/null 2>&1 && eval "$(goenv init -)"
# Java (macOS Homebrew)
[[ -d /opt/homebrew/opt/openjdk@11/bin ]] && export PATH="/opt/homebrew/opt/openjdk@11/bin:$PATH"
[[ -d /opt/homebrew/opt/openjdk@11 ]] && export JAVA_HOME=/opt/homebrew/opt/openjdk@11
# MySQL
[[ -d /usr/local/opt/mysql/bin ]] && export PATH="/usr/local/opt/mysql/bin:$PATH"
# Vitess
export VTDATAROOT=/tmp/vtdataroot
export VTROOT=~/git/twthorn/vitess
[[ -d "$HOME/git/twthorn/vitess/bin" ]] && export PATH="${PATH}:$HOME/git/twthorn/vitess/bin"
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Bash history settings
# Keep sessions separate but persist all commands immediately
shopt -s histappend               # Append history instead of overwriting
HISTSIZE=10000                    # Commands to keep in memory per session
HISTFILESIZE=50000                # Total commands to keep in file
HISTCONTROL=ignoredups:erasedups  # Ignore duplicates
HISTTIMEFORMAT='%F %T '           # Add timestamps to history

# Save history after each command (but don't reload from other sessions)
# This keeps sessions independent while ensuring all history is persisted
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

# prevent accidental shell exits
export IGNOREEOF=42

# git
alias gco='git checkout'
alias gdc="git diff --cached"
alias gp="git pull"
alias gpom="git push origin master"
alias gpoh="git push origin HEAD"
alias gmnf="git merge --no-ff"
alias gcm="git commit -m "
alias gcms="git commit -s -m "
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
    git checkout -b ${USER}_"$1"
}

gcou() {
    git checkout ${USER}__"$1"
}

gpohu() {
    git push origin HEAD:${USER}_"$1"
}


gcobui() {
    git_interceptor checkout -b ${USER}_"$1"
}

gcobi() {
    git_interceptor checkout -b "$1"
}

gcoui() {
    git_interceptor checkout ${USER}_"$1"
}

gpohui() {
    git_interceptor push origin HEAD:${USER}_"$1"
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
if [[ "$(uname)" == "Darwin" ]]; then
    alias ls='ls -G'
    export LSCOLORS="fxexcxdxbxegedabagacad"
else
    alias ls='ls --color=auto'
fi

# ctags
alias gentagpy="ctags -L <(find . -name '*.py' | cut -c3-) --fields=+iaS --python-kinds=-i --extra=+q -f .git/python.tags"

# ssh
alias fixssh='export $(tmux show-environment | grep \^SSH_AUTH_SOCK=)'

# tmux
alias t="tmux attach"
alias tnew='tmux new-session -s "$(echo $PWD | sed "s|$HOME/||")"'

# python
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

complete -W "\`grep -oE '^[a-zA-Z0-9_.-]+:([^=]|$)' Makefile | sed 's/[^a-zA-Z0-9_.-]*$//'\`" make

# Load private aliases/config if present (not tracked in git)
[[ -f ~/.bashrc_private ]] && source ~/.bashrc_private
