#!/usr/bin/env  pwsh
using namespace "System"
using namespace "System.Diagnostics"
using namespace "System.IO"

Write-Host "* Initializing PowerShell" -ForegroundColor Yellow

# Configure aliases to native commands.
function AliasLs { & "/usr/bin/ls" -l -A -h  --color $args }
Set-Alias -name ls -Value AliasLs -Option AllScope

function AliasGrep { & "/usr/bin/grep" --color=always $args }
Set-Alias -name grep -Value AliasGrep -Option Allscope

function AliasMC { & "/usr/bin/mc" --color --skin=nicedark $args }
Set-Alias -name mc -Value AliasMC -Option Allscope

function AliasReboot { exit $env:STOP_SHELL_REBOOT }
Set-Alias -name reboot -Value AliasReboot -Option Allscope

function AliasPoweroff { exit $env:STOP_SHELL_POWEROFF }
Set-Alias -name poweroff -Value AliasPoweroff -Option Allscope
Set-Alias -name shutdown -Value AliasPoweroff -Option Allscope

# Configure the prompt.
function prompt {
	$Hostname = "$env:HOSTNAME"
	$User = $( & "whoami")
	$Date = Get-Date -Format "ddd dd. MMM yyyy HH:mm"
	$Uptime = $( & "uptime" -p)
	$ESC = [Char]27
    "$ESC[00;37m$Hostname  $ESC[01;35m$User  $ESC[00;36m$Date  $ESC[00;34m$Uptime`n$ESC[01;33m" + $(Get-Location) + "`n$ESC[00;00m"+ $(if ($NestedPromptLevel -ge 1) { ">>" }) + "> "
}
