#!/bin/bash
for f in `ls -A | egrep '^\.' | grep -v .gitconfig | grep -v ".git$"`
do
    echo 'cp -r' $f $HOME
    cp -r $f $HOME
done
echo "appending gitconfig"
cat .gitconfig >> $HOME/.gitconfig
