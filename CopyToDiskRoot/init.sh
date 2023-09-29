#!/bin/sh
echo -n -e "\033[1;33m"
echo "* Initializing Linux system"
echo -n -e "\033[0;0m"

# Setting environment variables.
echo "  Setting environment variables"
export HOSTNAME=RpcLinuxDotNet
export LANG=da_DK
export LD_LIBRARY_PATH=/usr/lib:/usr/lib/x86_64-linux-gnu:/usr/lib64
export PATH=/usr/bin:/usr/sbin:/usr/lib:/usr/lib64:/tmp
export DOTNET_ROOT=/usr/lib64/dotnet
export DOTNET_CLI_TELEMETRY_OPTOUT=true
export PSHOME=/usr/lib64/powershell
export TERM=linux
#export TERM=xterm
#export CONFIG_FEATURE_EDITING_MAX_LEN=1024
#export SHELL=/usr/bin/sh
export HOME=/home/dotnet
export ENV=/home/root/init-shell.sh
export PS1="\$(echo \"\\n\\[\\033[00;37m\\]\\$HOSTNAME \\[\\033[01;35m\\]\\u \\[\\033[00;36m\\]\`date +\"%a %d. %b %Y %H.%M\"\` \\[\\033[00;34m\\]\`uptime -p\`\\n\\[\\033[01;33m\\]\\w\\[\\033[00;00m\\]\\n\$ \")"
export STOP_SHELL_POWEROFF=9
export STOP_SHELL_REBOOT=8

# Mount file systems.
echo "  Mounting file systems"
mount -t sysfs  sysfs  /sys
mount -t proc  proc  /proc
mount -t devtmpfs  udev  /dev
#mount -t devpts  dev/pts  /dev/pts

# Configure the kernel.
# Kernel log levels set with "kernel.printk": console_loglevel  default_message_loglevel  minimum_console_loglevel  default_console_loglevel
echo "  Setting kernel options"
sysctl -q -w kernel.printk="2 4 1 7"
sysctl -q -w net.ipv4.ping_group_range="0 2147483647"

# Configure the terminal.
# It is important to set the TTY size, when running on a serial TTY.
# The "resize" command is build into Busybox, and also awailable from the "xterm" package.
# It gets the terminal size in rows and columns by echoing "\033[18t", and setting with "stty columns ???  rows ??".
echo "  Setting terminal options"
loadkeys dk
resize


# Initialize network.
echo "  Initializing network"
ifconfig lo  127.0.0.1
ifconfig eth0  10.0.2.15
route add  default  gw  10.0.2.2

#    mount  -t nfs4  10.10.1.10:/setup  /mnt/setup
# Starting General Purpose Mouse daemon.
#/usr/sbin/gpm  /etc/gpm.conf  &

# check the window size after each command and, if necessary, # update the values of LINES and COLUMNS.
#shopt -s checkwinsize
#shopt -s histappend
#shopt -u inherit_errexit
#shopt -u shift_verbose

#histappend      on
#inherit_errexit off
#shift_verbose   off

# don't put duplicate lines or lines starting with space in the history.
#export HISTCONTROL=ignoreboth
#export HISTSIZE=1000
#export HISTFILESIZE=2000

stty sane




# Starting the shell.
# This uses the START_SHELL environment variable, which should be either "pwsh" or "sh". Defaults to "pwsh".
if [ "$START_SHELL" == "sh" ]; then
	echo "  Starting Shell"
	setsid cttyhack "/usr/bin/sh"
	STOP_SHELL="$?"
else
	echo "  Starting PowerShell"
	setsid cttyhack "/usr/bin/pwsh" -NoLogo -NoProfile -NoExit -WorkingDirectory "/home/dotnet" -File "/home/root/init-powershell.ps1"
	STOP_SHELL="$?"
fi

# Shutdown the machine.
# This uses the STOP_SHELL variable, which is the Exit Code fromm the shell, and should be either "9" for poweroff or
# "8" for reboot. All other values reboot aswell.
if [ "$STOP_SHELL" == "$STOP_SHELL_POWEROFF" ]; then
	echo -n -e "\033[1;31m"
	echo "* Poweroff system ($STOP_SHELL)"
	echo -n -e "\033[0;0m"
	sleep 3
	poweroff  -f
else
	echo -n -e "\033[1;32m"
	echo "* Rebooting system ($STOP_SHELL)"
	echo -n -e "\033[0;0m"
	sleep 3
	reboot  -f
fi
