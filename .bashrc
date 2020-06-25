#!/bin/bash
# If not running interactively, don't do anything
[[ $- == *i* ]] || return

# source bash prompt
source ~/.bash_prompt

# prevent accidental shell exits
export IGNOREEOF=42

# git
alias gco='git checkout'
alias gco="git checkout"
alias gdc="git diff --cached"
alias gp="git pull"
alias gpom="git push origin master"
alias gmnf="git merge --no-ff"
alias gcm="git commit -m "
alias gdom="git diff origin/master"
alias gs="git status"
alias gap="git add -p"

# shell
alias ls='ls -G'
export LSCOLORS="fxexcxdxbxegedabagacad"

# ctags
alias gentagpy="ctags -L <(find . -name '*.py' | cut -c3-) --fields=+iaS --python-kinds=-i --extra=+q -f .git/python.tags"


# ssh
alias fixssh='export $(tmux2 show-environment | grep \^SSH_AUTH_SOCK=)'

# tmux
alias t="tmux attach"

# python
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi
