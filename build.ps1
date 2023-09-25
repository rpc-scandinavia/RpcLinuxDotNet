#!/usr/bin/env  pwsh
# ┌────────────────────────────────────────────────────────────────────────────────┐
# │  SCRIPT: /RpcLinuxDotNet/build.ps1                                             │
# │ VERSION: 2023-09-10 Initial version                                            │
# │  SYSTEM: RPC / ITDD                                                            │
# │FUNCTION: This script builds the RPC .NET Linux for the x86_64 architecture.    │
# │                                                                                │
# │          The Linux kernel, Toybox, Busybox and Grub is compiled from source.   │
# │          Other files are extracted from downloaded DEB packages.               │
# │                                                                                │
# │          The following packages must be installed:                             │
# │            * binutils                                                          │
# │            * bison                                                             │
# │            * build-essential                                                   │
# │            * flex                                                              │
# │            * gcc                                                               │
# │            * gettext                                                           │
# │            * libelf-dev                                                        │
# │            * libncurses-dev                                                    │
# │            * libssl-dev                                                        │
# │            * linux-libc-dev                                                    │
# │            * make                                                              │
# │            * qemu-system-x86                                                   │
# │                                                                                │
# │          The following external commands are executed:                         │
# │            * bash                                                              │
# │            * chmod                                                             │
# │            * chown                                                             │
# │            * dpkg-deb                                                          │
# │            * ln                                                                │
# │            * make                                                              │
# │            * rsync                                                             │
# │            * tar                                                               │
# │            * unzip                                                             │
# │            * wget                                                              │
# │                                                                                │
# │          The following compiled programs are executed:                         │
# │            * toybox                                                            │
# │            * busybox                                                           │
# │            * grub-mkrescue                                                     │
# │                                                                                │
# │          Toybox vs. Busybox. As default, Toybox is used when both Toybox and   │
# │          Busybox implement a command. This can be owerridden by specifying     │
# │          which commands each should not link.                                  │
# │                                                                                │
# │                                                                                │
# └────────────────────────────────────────────────────────────────────────────────┘

using namespace "System"
using namespace "System.Diagnostics"
using namespace "System.IO"

# Variables.
$projectRootDirectory = "/data/users/rpc@rpc-scandinavia.dk/Development/RpcLinuxDotNet"
$projectLogsDirectory = "$projectRootDirectory/Logs"
$projectDownloadsDirectory = "$projectRootDirectory/Downloads"
$projectBinariesDirectory = "$projectRootDirectory/Binaries"
$projectPackagesDirectory = "$projectRootDirectory/Packages"
$projectCopyToDiskDirectory = "$projectRootDirectory/CopyToDisk"
$projectDiskDirectory = "$projectRootDirectory/Disk"
$projectDiskImageFile = "$projectRootDirectory/Binaries/disk.img"
$projectDiskIsoFile = "$projectRootDirectory/Binaries/rpc-linux-dotnet.iso"

$kernelDownloadFileName = "linux-kernel.tar.gz"
$kernelBinaryFileName = "linux-kernel"
$toyboxDownloadFileName = "toybox.zip"
$toyboxDoNotLink = @("wget")
$busyboxDownloadFileName = "busybox.tar.bz2"
$busyboxDoNotLink = @()
$grubDownloadFileName = "grub.tar.xz"
$grubInstallDirectory = "$projectRootDirectory/Binaries/grub-installation"

$makeJobs = 2

# Array with array elements (sourceUrl, targetDirectory | targetFile).
# Note that starting with the comma, ensures that the array works with one array element.
$projectDownloads = @(
	# Download source code.
	, @("https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/linux-6.4.9.tar.gz", "$projectDownloadsDirectory/$kernelDownloadFileName")
	, @("https://github.com/landley/toybox/archive/refs/heads/master.zip", "$projectDownloadsDirectory/$toyboxDownloadFileName")
	, @("https://www.busybox.net/downloads/busybox-1.36.1.tar.bz2", "$projectDownloadsDirectory/$busyboxDownloadFileName")
	, @("https://ftp.gnu.org/gnu/grub/grub-2.06.tar.xz", "$projectDownloadsDirectory/$grubDownloadFileName")

	# Download Debian packages, dependencies to run .NET runtime.
	, @("http://ftp.dk.debian.org/debian/pool/main/g/glibc/libc6_2.36-9+deb12u1_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/g/gcc-12/libgcc-s1_12.2.0-14_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/g/gcc-12/gcc-12-base_12.2.0-14_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/k/krb5/libgssapi-krb5-2_1.20.1-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/e/e2fsprogs/libcom-err2_1.47.0-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/libx/libxcrypt/libcrypt1_4.4.33-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/k/krb5/libk5crypto3_1.20.1-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/k/krb5/libkrb5support0_1.20.1-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/k/krb5/libkrb5-3_1.20.1-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/k/keyutils/libkeyutils1_1.6.3-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/i/icu/libicu72_72.1-3_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/o/openssl/libssl3_3.0.9-1_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/g/gcc-12/libatomic1_12.2.0-14_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/g/gcc-12/libstdc++6_12.2.0-14_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/z/zlib/zlib1g_1.2.13.dfsg-1_amd64.deb", "$projectPackagesDirectory")

	# Download Debian packages, Midtnight Commander and dependencies.
	, @("http://ftp.dk.debian.org/debian/pool/main/m/mc/mc_4.8.29-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/e/e2fsprogs/libext2fs2_1.47.0-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/g/glib2.0/libglib2.0-0_2.74.6-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/libf/libffi/libffi8_3.4.4-1_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/u/util-linux/libmount1_2.38.1-5+b1_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/u/util-linux/libblkid1_2.38.1-5+b1_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/libs/libselinux/libselinux1_3.4-1+b6_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/p/pcre2/libpcre2-8-0_10.42-1_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/s/slang2/libslang2_2.3.3-3_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/g/gpm/libgpm2_1.20.7-10+b1_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/libs/libssh2/libssh2-1_1.10.0-3+b1_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/d/debconf/debconf_1.5.82_all.deb", "$projectPackagesDirectory")
)



function Download {
	param ($force)

	Write-Host "* Downloading" -ForegroundColor Yellow
	foreach ($projectDownload in $projectDownloads) {
		$sourceUrl = $projectDownload[0]
		$targetFile = $projectDownload[1]

		# If target file is a directory, then get the file name from the source.
		if (Test-Path -Path "$targetFile" -PathType Container) {
			$targetFile = [System.IO.Path]::Combine($targetFile, [System.IO.Path]::GetFileName($sourceUrl))
		}

		if ((-not (Test-Path "$targetFile" -PathType Leaf)) -or ($force -eq $true)) {
			Write-Host "   From: '$sourceUrl'`n     To: '$targetFile'"
			$exitCode = Execute "wget" "--quiet --output-document=""$targetFile"" ""$sourceUrl""" $false 0
			if ($exitCode -ne 0) {
				if (Test-Path "$targetFile") {
					Remove-Item "$targetFile"
				}
			}
		}
	}
} # Download

function BuildLinuxKernel {
	Write-Host "* Building Linux kernel" -ForegroundColor Yellow

	# Create temporary directory and set it as the current directory.
	$tempDirectory = NewTemporaryDirectory
	Set-Location -Path "$tempDirectory"
	Write-Host "  Using temp directory '$tempDirectory'"

	# Extracting the source code.
	Write-Host "  Extracting files"
	$exitCode = Execute "tar" "--extract --file=""$projectDownloadsDirectory/$kernelDownloadFileName"" --directory=""$tempDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}
	$buildDirectory = (Get-ChildItem -Path "$tempDirectory" -Directory -Force -ErrorAction SilentlyContinue)[0]
	Set-Location -Path "$buildDirectory"

	# Configuring the source code.
	Write-Host "  Configuring"
	$exitCode = Execute "make" "--silent  defconfig" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Compiling the source code.
	Write-Host "  Compiling"
	$exitCode = Execute "make" "--silent  --jobs=$makeJobs" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Copy the binary file.
	Write-Host "  Copying"
	Copy-Item -Path "$buildDirectory/arch/x86_64/boot/bzImage" -Destination "$projectBinariesDirectory/$kernelBinaryFileName" -Force

	# Remove temporary directory.
	Set-Location -Path "$currentDirectory"
	if (Test-Path "$tempDirectory" -PathType Container) {
		Write-Host "  Removing temp directory"
		Remove-Item -Recurse -Force "$tempDirectory"
	}
} # BuildLinuxKernel

function BuildToybox {
	Write-Host "* Building Toybox" -ForegroundColor Yellow

	# Create temporary directory and set it as the current directory.
	$tempDirectory = NewTemporaryDirectory
	Set-Location -Path "$tempDirectory"
	Write-Host "  Using temp directory '$tempDirectory'"

	# Extracting the source code.
	Write-Host "  Extracting files"
	$exitCode = Execute "unzip" "-qq ""$projectDownloadsDirectory/$toyboxDownloadFileName"" -d ""$tempDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}
	$buildDirectory = (Get-ChildItem -Path "$tempDirectory" -Directory -Force -ErrorAction SilentlyContinue)[0]
	Set-Location -Path "$buildDirectory"

	# Configuring the source code.
	Write-Host "  Configuring"
	$exitCode = Execute "make" "--silent  defconfig" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Compiling the source code.
	Write-Host "  Compiling"
	$exitCode = Execute "make" "--silent  --jobs=$makeJobs" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Copy the binary file.
	Write-Host "  Copying"
	Copy-Item -Path "$buildDirectory/toybox" -Destination "$projectBinariesDirectory/toybox" -Force

	# Remove temporary directory.
	Set-Location -Path "$currentDirectory"
	if (Test-Path "$tempDirectory" -PathType Container) {
		Write-Host "  Removing temp directory"
		Remove-Item -Recurse -Force "$tempDirectory"
	}
} # BuildToybox

function BuildBusybox {
	Write-Host "* Building Busybox" -ForegroundColor Yellow

	# Create temporary directory and set it as the current directory.
	$tempDirectory = NewTemporaryDirectory
	Set-Location -Path "$tempDirectory"
	Write-Host "  Using temp directory '$tempDirectory'"

	# Extracting the source code.
	Write-Host "  Extracting files"
	$exitCode = Execute "tar" "--extract --file=""$projectDownloadsDirectory/$busyboxDownloadFileName"" --directory=""$tempDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}
	$buildDirectory = (Get-ChildItem -Path "$tempDirectory" -Directory -Force -ErrorAction SilentlyContinue)[0]
	Set-Location -Path "$buildDirectory"

	# Configuring the source code.
	Write-Host "  Configuring"
	$exitCode = Execute "make" "--silent  defconfig" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Enable static linking in the configuration file.
	#	# CONFIG_STATIC is not set
	#	CONFIG_STATIC=y
	((Get-Content -path "$buildDirectory/.config" -Raw) -replace "# CONFIG_STATIC is not set", "CONFIG_STATIC=y")  |  Set-Content -Path "$buildDirectory/.config"

	# Compiling the source code.
	Write-Host "  Compiling"
	$exitCode = Execute "make" "--silent  --jobs=$makeJobs" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Copy the binary file.
	Write-Host "  Copying"
	Copy-Item -Path "$buildDirectory/busybox" -Destination "$projectBinariesDirectory/busybox" -Force

	# Remove temporary directory.
	Set-Location -Path "$currentDirectory"
	if (Test-Path "$tempDirectory" -PathType Container) {
		Write-Host "  Removing temp directory"
		Remove-Item -Recurse -Force "$tempDirectory"
	}
} # BuildBusybox

function BuildGrub {
	Write-Host "* Building Grub" -ForegroundColor Yellow

	# Create temporary directory and set it as the current directory.
	$tempDirectory = NewTemporaryDirectory
	Set-Location -Path "$tempDirectory"
	Write-Host "  Using temp directory '$tempDirectory'"

	# Extracting the source code.
	Write-Host "  Extracting files"
	$exitCode = Execute "tar" "--extract --file=""$projectDownloadsDirectory/$grubDownloadFileName"" --directory=""$tempDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}
	$buildDirectory = (Get-ChildItem -Path "$tempDirectory" -Directory -Force -ErrorAction SilentlyContinue)[0]
	Set-Location -Path "$buildDirectory"

	# Configuring the source code.
	Write-Host "  Configuring"
	$exitCode = Execute "./configure" "--disable-werror --target=x86_64 --with-platform=pc --prefix ""$grubInstallDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Compiling the source code.
	Write-Host "  Compiling"
	$exitCode = Execute "make" "--silent  --jobs=$makeJobs" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Installing the binary files into the Grub install directory that was specified when configuring.
	Write-Host "  Installing into '$grubInstallDirectory'"
	$exitCode = Execute "make" "install" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Remove temporary directory.
	Set-Location -Path "$currentDirectory"
	if (Test-Path "$tempDirectory" -PathType Container) {
		Write-Host "  Removing temp directory"
		Remove-Item -Recurse -Force "$tempDirectory"
	}
} # BuildGrub

function CreateDiskDirectory {
	Write-Host "* Building disk directory" -ForegroundColor Yellow

	# Remove existing files.
	if (Test-Path "$projectDiskDirectory" -PathType Any) {
		Write-Host "  Removing existing files"
		Remove-Item -Recurse -Force "$projectDiskDirectory"
	}

	# Create directories.
	# Note that the linked directories from "/usr" are not created.
	Write-Host "  Creating directories"
	New-Item -ItemType Directory -Force -Path "$projectDiskDirectory"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/dev"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/dev/pts"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/etc"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/home"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/home/root"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/home/guest"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/mnt"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/mnt/setup"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/proc"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/root"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/sys"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/tmp"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/var"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/usr"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/usr/bin"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/usr/sbin"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/usr/lib"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/usr/lib32"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/usr/lib64"  |  Out-Null

	# Linking directories.
	Write-Host "  Linking directories"
	$exitCode = Execute "ln" "--force --symbolic --relative ""$projectDiskDirectory/usr/bin"" ""$projectDiskDirectory""" $false (0, 1)
	$exitCode = Execute "ln" "--force --symbolic --relative ""$projectDiskDirectory/usr/sbin"" ""$projectDiskDirectory""" $false (0, 1)
	$exitCode = Execute "ln" "--force --symbolic --relative ""$projectDiskDirectory/usr/lib"" ""$projectDiskDirectory""" $false (0, 1)
	$exitCode = Execute "ln" "--force --symbolic --relative ""$projectDiskDirectory/usr/lib32"" ""$projectDiskDirectory""" $false (0, 1)
	$exitCode = Execute "ln" "--force --symbolic --relative ""$projectDiskDirectory/usr/lib64"" ""$projectDiskDirectory""" $false (0, 1)

	# Installing Busybox.
	# Note that getting the command list is only possible, because the build environment and the target system is the same architecture (x86_64).
	Write-Host "  Copying Busybox"
	Copy-Item -Path "$projectBinariesDirectory/busybox" -Destination "$projectDiskDirectory/usr/bin/busybox" -Force

	Write-Host "  Linking Busybox"
	$stdout = Execute "$projectDiskDirectory/usr/bin/busybox" "--list" $true 0
	foreach ($command in $stdout -split '\r?\n') {
		if (($command -ne "") -and ($command -inotmatch "\[") -and ($busyboxDoNotLink -notcontains $command)) {
			$exitCode = Execute "ln" "--force --symbolic --relative ""$projectDiskDirectory/usr/bin/busybox"" ""$projectDiskDirectory/usr/bin/$command""" $false 0
		}
	}

	# Installing Toybox.
	# After Busybox, so existing links are replaced.
	# Note that getting the command list is only possible, because the build environment and the target system is the same architecture (x86_64).
	Write-Host "  Copying Toybox"
	Copy-Item -Path "$projectBinariesDirectory/toybox" -Destination "$projectDiskDirectory/usr/bin/toybox" -Force

	Write-Host "  Linking Toybox"
	$stdout = Execute "$projectDiskDirectory/usr/bin/toybox" "--long --help" $true 0
	foreach ($command in $stdout -split ' |\r?\n') {
		$command = [System.IO.Path]::GetFileName($command)		# Toybox return the full path.
		if (($command -ne "") -and ($command -inotmatch "\[") -and ($toyboxDoNotLink -notcontains $command)) {
			$exitCode = Execute "ln" "--force --symbolic --relative ""$projectDiskDirectory/usr/bin/toybox"" ""$projectDiskDirectory/usr/bin/$command""" $false 0
		}
	}

	# Extract DEB packages.
	# If we use "dkpg-deb" to extract the files directly to the desired destination, some files/directories that are
	# symbolic links are overwritten. This is awoided by extracting the filed to a temporary directory, and then copying
	# the files to the desired destinatiion.
	# Also notice "-ErrorAction SilentlyContinue" when copying, this ignores dead symbolic links.
	foreach ($package in Get-ChildItem "$projectPackagesDirectory" -Recurse "*.deb") {
		Write-Host "  Copying files from package '$([System.IO.Path]::GetFileName($package))'"

		# Create temporary directory and set it as the current directory.
		$tempDirectory = NewTemporaryDirectory

		# Extract into temporary directory.
		$exitCode = Execute "dpkg-deb" "--extract ""$package"" ""$tempDirectory""" $false 0
		if ($exitCode -ne 0) {
			EndProgram $exitCode
		}

		# Copy extracted files.
		$exitCode = Execute "rsync" "--archive --keep-dirlinks ""$tempDirectory/"" ""$projectDiskDirectory""" $false 0

		# Remove temporary directory.
		if (Test-Path "$tempDirectory" -PathType Container) {
			Remove-Item -Recurse -Force "$tempDirectory"
		}
	}

	# Copy additional files.
	Write-Host "  Copying additional files"
	Copy-Item -Path "$projectCopyToDiskDirectory/*" -Destination "$projectDiskDirectory" -Force -Recurse  |  Out-Null
} # CreateDiskDirectory

function WriteDiskFiles {
	Write-Host "* Creating disk files" -ForegroundColor Yellow

    # INIT script.
	Write-Host "  '/init'"
	$text = @"
#!/bin/sh

export  HOME=/root
export  PATH=/usr/bin:/usr/sbin:/usr/lib:/usr/lib64:/tmp
export  LD_LIBRARY_PATH=/usr/lib:/usr/lib/x86_64-linux-gnu:/usr/lib64
export  LANG=en_DK.UTF-8
export  TERM=vt100
export  PS1='`$(echo "\n\[\033[01;37m\]\H \[\033[01;34m\]``uptime -p`` \[\033[01;32m\]\u \[\033[01;96m\]``date +"%a %d. %b %Y %H.%M"``\n\[\033[01;33m\]\w \[\033[00m\]\n`$ ")'
export  ENV=/init.sh

mount  -t sysfs  sysfs  /sys
mount  -t proc  proc  /proc
mount  -t devtmpfs  udev  /dev
#mount  -t devpts  dev/pts  /dev/pts

sysctl -w kernel.printk=""2 4 1 7""
sysctl -w net.ipv4.ping_group_range=""0 2147483647""

ifconfig  lo  127.0.0.1
ifconfig  eth0  10.0.2.15
route  add  default  gw  10.0.2.2

#    mount  -t nfs4  10.10.1.10:/setup  /mnt/setup

echo  ""*** Run 'exit' to shutdown the system ***""
setsid  cttyhack  /bin/sh
#/bin/sh
poweroff  -f
"@
	$text  |  Out-File -FilePath "$projectDiskDirectory/init"

    # Init shell script.
	Write-Host "  '/init.sh'"
	$text = @"
#!/bin/sh
alias  ls="ls  -lAh  --color"

stty  columns 150  rows 40

# Allow the command prompt to wrap to the next line
set  horizontal-scroll-mode Off

# Enable 8-bit input
set  meta-flag On
set  input-meta On

# Turns off 8th bit stripping
set  convert-meta Off

# Keep the 8th bit for display
set  output-meta On

# none, visible or audible
set  bell-style none

## All of the following map the escape sequence of the value
## contained in the 1st argument to the readline specific functions
#\"\\eOd\": backward-word
#\"\\eOc\": forward-word
#
## for linux console
#\"\\e[1~\": beginning-of-line
#\"\\e[4~\": end-of-line
#\"\\e[5~\": beginning-of-history
#\"\\e[6~\": end-of-history
#\"\\e[3~\": delete-char
#\"\\e[2~\": quoted-insert
#
## for xterm
#\"\\eOH\": beginning-of-line
#\"\\eOF\": end-of-line
#
## for Konsole
#\"\\e[H\": beginning-of-line
#\"\\e[F\": end-of-line
"@
	$text  |  Out-File -FilePath "$projectDiskDirectory/init.sh"

    # Users and Groups.
	Write-Host "  '/etc/passwd'"
	$text = @"
root::0:0:root:/home/root:/bin/sh
guest:x:500:500:guest:/home/guest:/bin/sh
"@
	$text  |  Out-File -FilePath "$projectDiskDirectory/etc/passwd"

	Write-Host "  '/etc/group'"
	$text = @"
root:x:0:
guest:x:500:
"@
	$text  |  Out-File -FilePath "$projectDiskDirectory/etc/group"

	Write-Host "  '/etc/hostname'"
	$text = @"
Test
"@
	$text  |  Out-File -FilePath "$projectDiskDirectory/etc/hostname"

	Write-Host "  '/etc/resolv.conf'"
	$text = @"
nameserver  1.1.1.1
"@
	$text  |  Out-File -FilePath "$projectDiskDirectory/etc/resolv.conf"

} # WriteDiskFiles

function CreateDiskImage {
	Write-Host "* Creating disk image" -ForegroundColor Yellow

	# Set permissions.
	$exitCode = Execute "chmod" "--recursive 777 ""$projectDiskDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	#$exitCode = Execute "chown" "--recursive 0:900 ""$projectDiskDirectory""" $false 0
	#if ($exitCode -ne 0) {
	#	EndProgram $exitCode
	#}

	# Create disk image.
	Set-Location -Path "$projectDiskDirectory"
	$exitCode = Execute "bash" "-c ""find . | cpio --create --format=newc  >  '$projectDiskImageFile'""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	Set-Location -Path "$currentDirectory"
} # CreateDiskImage

function CreateISO {
	Write-Host "* Creating disk ISO" -ForegroundColor Yellow

	# Create temporary directory and set it as the current directory.
	$tempDirectory = NewTemporaryDirectory

	# Create directories.
    New-Item -ItemType Directory -Force -Path "$tempDirectory/boot"  |  Out-Null
    New-Item -ItemType Directory -Force -Path "$tempDirectory/boot/grub"  |  Out-Null

	# Copy the Linux kernel file.
	Write-Host "  Copying Linux kernel"
	Copy-Item -Path "$projectBinariesDirectory/$kernelBinaryFileName" -Destination "$tempDirectory/boot" -Force

	# Copy the disk image file.
	Write-Host "  Copying disk image"
	Copy-Item -Path "$projectDiskImageFile" -Destination "$tempDirectory/boot" -Force

    # Grub configuration.
	Write-Host "  Creating '/boot/grub/grub.cfg'"
	$kernelFileName = [System.IO.Path]::GetFileName("$projectBinariesDirectory/$kernelBinaryFileName")
	$imageFileName = [System.IO.Path]::GetFileName("$projectDiskImageFile")
	$text = @"
set  default = 0
set  timeout = 10

menuentry  'RPC .NET Linux'  --class os {
     insmod  gzio
     insmod  part_msdos
     linux  /boot/$kernelFileName
     initrd  /boot/$imageFileName
}
"@
	$text  |  Out-File -FilePath "$tempDirectory/boot/grub/grub.cfg"

	# Create the ISO file.
	Write-Host "  Creating ISO file"
	$exitCode = Execute "$grubInstallDirectory/bin/grub-mkrescue" "--verbose  -output ""$projectDiskIsoFile""  ""$tempDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Remove temporary directory.
	if (Test-Path "$tempDirectory" -PathType Container) {
		Remove-Item -Recurse -Force "$tempDirectory"
	}
} # CreateISO

function RunDiskImage {
	Write-Host "* Running Linux kernel with disk image" -ForegroundColor Yellow

	# Use Start-Process directly, because we want I/O.
	Start-Process "qemu-system-x86_64" -Wait -PassThru -ArgumentList "-kernel ""$projectBinariesDirectory/$kernelBinaryFileName"" -initrd ""$projectDiskImageFile"" -append ""panic=1  console=ttyS0"" -nographic -k da  -m size=2048 -nic user,model=virtio-net-pci"

	Write-Host "* Finished running Linux kernel with disk image" -ForegroundColor Yellow
} # RunDiskImage


function Execute {
	param ([String]$command, [String]$arguments, [Boolean]$returnStdOut, [Int32[]]$successExitCodes)

	if ($returnStdOut -eq $false) {
		Try {
			$process = Start-Process "$command" -Wait -PassThru -ArgumentList "$arguments" -ErrorAction SilentlyContinue -RedirectStandardOutput "$projectLogsDirectory/stoout.txt" -RedirectStandardError "$projectLogsDirectory/stderr.txt"
			$processExitCode = $process.ExitCode
			if ($successExitCodes -notcontains $processExitCode) {
				Write-Host "  Error: $processExitCode" -ForegroundColor Red
			}

			return $processExitCode
		} Catch {
			Write-Host "  Error: Exception" -ForegroundColor Red
			return -1
		}
	} else {
		Try {
			$processInfo = New-Object System.Diagnostics.ProcessStartInfo
			$processInfo.FileName = $command
			$processInfo.RedirectStandardError = $true
			$processInfo.RedirectStandardOutput = $true
			$processInfo.UseShellExecute = $false
			$processInfo.Arguments = $arguments
			$process = New-Object System.Diagnostics.Process
			$process.StartInfo = $processInfo
			$process.Start()  |  Out-Null
			$process.WaitForExit()
			$stdout = $process.StandardOutput.ReadToEnd()
			return $stdout
		} Catch {
			return ""
		}
	}
} # Execute

function NewTemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    $name = [System.Guid]::NewGuid().ToString()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
} # NewTemporaryDirectory

function EndProgram {
	param ([Int32]$exitCode)

	# Set the current directory.
	Set-Location -Path "$currentDirectory"

	# Exit.
	$host.SetShouldExit($exitCode)
	exit $exitCode
} # EndProgram



# Clear the console.
Clear-Host

# Get the current directory.
$currentDirectory = (Get-Location).Path

# Create project directories.
New-Item -ItemType Directory -Force -Path "$projectRootDirectory"  |  Out-Null
New-Item -ItemType Directory -Force -Path "$projectLogsDirectory"  |  Out-Null
New-Item -ItemType Directory -Force -Path "$projectDownloadsDirectory"  |  Out-Null
New-Item -ItemType Directory -Force -Path "$projectBinariesDirectory"  |  Out-Null
New-Item -ItemType Directory -Force -Path "$projectPackagesDirectory"  |  Out-Null
New-Item -ItemType Directory -Force -Path "$projectCopyToDiskDirectory"  |  Out-Null
New-Item -ItemType Directory -Force -Path "$grubInstallDirectory"  |  Out-Null
New-Item -ItemType Directory -Force -Path "$projectDiskDirectory"  |  Out-Null

# Run.
Download
BuildLinuxKernel
BuildToybox
BuildBusybox
BuildGrub
CreateDiskDirectory
WriteDiskFiles
CreateDiskImage
CreateISO
RunDiskImage
EndProgram 0
