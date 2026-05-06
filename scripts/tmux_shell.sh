#!/bin/bash
# Spawns bash without the readonly TMOUT from /etc/profile.d/Z99-tmout.sh
unset TMOUT
exec bash --rcfile ~/.bashrc
