#!/bin/bash
for f in `ls -A | egrep '^\.' | grep -v .gitconfig | grep -v ".git$"`
do
    echo 'cp -r' $f $HOME
    cp -r $f $HOME
done
echo "setting up ctags in git configs"
git config --global init.templatedir '~/.git_template'
git config --global alias.ctags '!.git/hooks/ctags'
