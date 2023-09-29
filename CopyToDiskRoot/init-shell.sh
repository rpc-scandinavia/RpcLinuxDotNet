#!/bin/sh
echo -n -e "\033[1;33m"
echo "* Initializing Shell"
echo -n -e "\033[0;0m"

echo "  Creating aliases"
alias ls="ls -l -A -h --color"
alias mc="grep --color=always"
alias mc="mc --color --skin=nicedark"
alias pwsh="/usr/bin/pwsh -NoLogo -NoProfile -NoExit -WorkingDirectory /home/dotnet -File /home/root/init-powershell.ps1"
alias reboot="exit $STOP_SHELL_REBOOT"
alias poweroff="exit $STOP_SHELL_POWEROFF"
alias shutdown="exit $STOP_SHELL_POWEROFF"

# Set the current directory.
cd "$HOME"

# check the window size after each command and, if necessary, # update the values of LINES and COLUMNS.
#shopt -s checkwinsize
#shopt -s histappend
#shopt -u inherit_errexit
#shopt -u shift_verbose

#HISTCONTROL=ignoreboth
#HISTSIZE=1000
#HISTFILESIZE=2000

## Allow the command prompt to wrap to the next line
#set  horizontal-scroll-mode On



## Enable 8-bit input
#set  meta-flag On
#set  input-meta On
#
## Turns off 8th bit stripping
#set  convert-meta Off






## Keep the 8th bit for display
#set  output-meta On
#
## none, visible or audible
#set  bell-style none

## All of the following map the escape sequence of the value
## contained in the 1st argument to the readline specific functions
#"\eOd": backward-word
#"\eOc": forward-word
#
## for linux console
#"\e[1~": beginning-of-line
#"\e[4~": end-of-line
#"\e[5~": beginning-of-history
#"\e[6~": end-of-history
#"\e[3~": delete-char
#"\e[2~": quoted-insert
#
## for xterm
#"\eOH": beginning-of-line
#"\eOF": end-of-line
#
## for Konsole
#"\e[H": beginning-of-line
#"\e[F": end-of-line
