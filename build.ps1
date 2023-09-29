#!/usr/bin/env  pwsh
# ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
# │  SCRIPT: /RpcLinuxDotNet/build.ps1                                                                                 │
# │ VERSION: 2023-09-10 Initial version                                                                                │
# │  SYSTEM: RPC Linux .NET                                                                                            │
# │FUNCTION: This script builds the RPC Linux .NET for the x86_64 architecture.                                        │
# │                                                                                                                    │
# │          The Linux kernel, Toybox, Busybox and Grub is compiled from source.                                       │
# │          Other files are extracted from downloaded DEB packages.                                                   │
# │                                                                                                                    │
# │          The following packages must be installed:                                                                 │
# │            * binutils                                                                                              │
# │            * bison                                                                                                 │
# │            * build-essential                                                                                       │
# │            * flex                                                                                                  │
# │            * gcc                                                                                                   │
# │            * gettext                                                                                               │
# │            * libelf-dev                                                                                            │
# │            * libncurses-dev                                                                                        │
# │            * libssl-dev                                                                                            │
# │            * linux-libc-dev                                                                                        │
# │            * make                                                                                                  │
# │            * qemu-system-x86                                                                                       │
# │                                                                                                                    │
# │          The following external commands are executed:                                                             │
# │            * bash                                                                                                  │
# │            * chmod                                                                                                 │
# │            * chown                                                                                                 │
# │            * dpkg-deb                                                                                              │
# │            * ln                                                                                                    │
# │            * make                                                                                                  │
# │            * rsync                                                                                                 │
# │            * tar                                                                                                   │
# │            * unzip                                                                                                 │
# │            * wget                                                                                                  │
# │                                                                                                                    │
# │          The following compiled programs are executed:                                                             │
# │            * toybox                                                                                                │
# │            * busybox                                                                                               │
# │            * grub-mkrescue                                                                                         │
# │                                                                                                                    │
# │          Toybox vs. Busybox. As default, Toybox is used when both Toybox and Busybox implement a command.          │
# │          This can be owerridden by specifying which commands each should not link.                                 │
# │                                                                                                                    │
# │                                                                                                                    │
# └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

using namespace "System"
using namespace "System.Diagnostics"
using namespace "System.IO"

# Variables.
$projectRootDirectory = "$PSScriptRoot"
$projectLogsDirectory = "$projectRootDirectory/Logs"
$projectDownloadsDirectory = "$projectRootDirectory/Downloads"
$projectBinariesDirectory = "$projectRootDirectory/Binaries"
$projectPackagesDirectory = "$projectRootDirectory/Packages"
$projectCopyToDiskDirectory = "$projectRootDirectory/CopyToDisk"
$projectCopyToDiskDirectoryRoot = "$projectRootDirectory/CopyToDiskRoot"
$projectCopyToDiskDirectoryDotNet = "$projectRootDirectory/CopyToDiskDotNet"
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
$grubPcInstallDirectory = "$projectRootDirectory/Binaries/grub-pc-installation"
$grubEfiInstallDirectory = "$projectRootDirectory/Binaries/grub-efi-installation"
$DotNetRuntimeDownloadFileName = "dotnet-runtime.tar.gz"
$DotNetSdkDownloadFileName = "dotnet-sdk.tar.gz"
$DotNetDiskDirectory = "/usr/lib64/dotnet"
$PowerShellDownloadFileName = "powershell.tar.gz"
$PowerShellDiskDirectory = "/usr/lib64/powershell"

$makeJobs = 4
$kernelParameters = "rdinit=/home/root/init.sh  panic=1  nomodeset  i915.modeset=0"	#modeset=1  fbcon=scrollback:1024k"
$kernelParametersGrub = "$kernelParameters vga=790"
$kernelParametersQemu = "$kernelParameters"

# FRAMEBUFFER RESOLUTION SETTINGS
# +-------------------------------------------------+
# | 640x480 800x600 1024x768 1280x1024
# ----+--------------------------------------------
# 256 | 0x301=769 0x303=771 0x305=773 0x307=775
# 32K | 0x310=784 0x313=787 0x316=790 0x319=793
# 64K | 0x311=785 0x314=788 0x317=791 0x31A=794
# 16M | 0x312=786 0x315=789 0x318=792 0x31B=795
# +-------------------------------------------------+


# Array with array elements (sourceUrl, targetDirectory | targetFile).
# Note that starting with the comma, ensures that the array works with one array element.
$projectDownloads = @(
	# Download source code.
	, @("https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/linux-6.4.9.tar.gz", "$projectDownloadsDirectory/$kernelDownloadFileName")
	, @("https://github.com/landley/toybox/archive/refs/heads/master.zip", "$projectDownloadsDirectory/$toyboxDownloadFileName")
	, @("https://www.busybox.net/downloads/busybox-1.36.1.tar.bz2", "$projectDownloadsDirectory/$busyboxDownloadFileName")
	, @("https://ftp.gnu.org/gnu/grub/grub-2.06.tar.xz", "$projectDownloadsDirectory/$grubDownloadFileName")

	# Download Debian packages, dependencies to run .NET Runtime and SDK.
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

	# Download .NET Runtime and SDK and PowerShell.
	, @("https://download.visualstudio.microsoft.com/download/pr/dc2c0a53-85a8-4fda-a283-fa28adb5fbe2/8ccade5bc400a5bb40cd9240f003b45c/aspnetcore-runtime-7.0.11-linux-x64.tar.gz", "$projectDownloadsDirectory/$DotNetRuntimeDownloadFileName")
	, @("https://download.visualstudio.microsoft.com/download/pr/61f29db0-10a5-4816-8fd8-ca2f71beaea3/e15fb7288eb5bc0053b91ea7b0bfd580/dotnet-sdk-7.0.401-linux-x64.tar.gz", "$projectDownloadsDirectory/$DotNetSdkDownloadFileName")
	, @("https://github.com/PowerShell/PowerShell/releases/download/v7.3.7/powershell-7.3.7-linux-x64.tar.gz", "$projectDownloadsDirectory/$PowerShellDownloadFileName")

#	# Download BASH.
#	, @("http://ftp.dk.debian.org/debian/pool/main/b/bash/bash_5.2.15-2+b2_amd64.deb", "$projectPackagesDirectory")
#	, @("http://ftp.dk.debian.org/debian/pool/main/n/ncurses/libtinfo6_6.4-4_amd64.deb", "$projectPackagesDirectory")
#	, @("http://ftp.dk.debian.org/debian/pool/main/b/base-files/base-files_12.4+deb12u1_amd64.deb", "$projectPackagesDirectory")
#	, @("http://ftp.dk.debian.org/debian/pool/main/m/mawk/mawk_1.3.4.20200120-3.1_amd64.deb", "$projectPackagesDirectory")
#	, @("http://ftp.dk.debian.org/debian/pool/main/m/meshoptimizer/libmeshoptimizer-dev_0.18+dfsg-2_amd64.deb", "$projectPackagesDirectory")
#	, @("http://ftp.dk.debian.org/debian/pool/main/m/meshoptimizer/libmeshoptimizer2d_0.18+dfsg-2_amd64.deb", "$projectPackagesDirectory")

	# Download Debian packages, Midtnight Commander and dependencies.
	, @("http://ftp.dk.debian.org/debian/pool/main/m/mc/mc_4.8.29-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/m/mc/mc-data_4.8.29-2_all.deb", "$projectPackagesDirectory")
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

	# Testing terminal.
	, @("http://ftp.dk.debian.org/debian/pool/main/d/directfb/libdirectfb-1.7-7_1.7.7-11_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/d/directfb/libdirectfb-bin_1.7.7-11_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/d/directfb/lib++dfb-1.7-7_1.7.7-11_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/f/freetype/libfreetype6_2.12.1+dfsg-5_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/libp/libpng1.6/libpng16-16_1.6.39-2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/b/brotli/libbrotli1_1.0.9-2+b6_amd64.deb", "$projectPackagesDirectory")

	# Testing.
	, @("http://ftp.dk.debian.org/debian/pool/main/f/fbset/fbset_2.1-33_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/m/makedev/makedev_2.3.1-97_all.deb", "$projectPackagesDirectory")

	, @("http://ftp.dk.debian.org/debian/pool/main/t/tar/tar_1.34+dfsg-1.2_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/a/acl/libacl1_2.3.1-3_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/c/console-data/console-data_1.12-9_all.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/c/console-common/console-common_0.7.91_all.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/d/debianutils/debianutils_5.7-0.4_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/k/kbd/kbd_2.5.1-1+b1_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/c/console-setup/console-setup_1.221_all.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/g/glibc/locales_2.36-9+deb12u1_all.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/g/glibc/libc-bin_2.36-9+deb12u1_amd64.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/g/glibc/libc-l10n_2.36-9+deb12u1_all.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/x/xkeyboard-config/xkb-data_2.35.1-1_all.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/c/console-setup/keyboard-configuration_1.221_all.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/n/ncurses/lib64ncurses6_6.4-4_i386.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/n/ncurses/lib64tinfo6_6.4-4_i386.deb", "$projectPackagesDirectory")
	, @("http://ftp.dk.debian.org/debian/pool/main/g/glibc/libc6-amd64_2.36-9+deb12u1_i386.deb", "$projectPackagesDirectory")
#	, @("http://ftp.dk.debian.org/debian/pool/main/g/gpm/gpm_1.20.7-10+b1_amd64.deb", "$projectPackagesDirectory")
)



function Download {
	param ([Boolean]$force)

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
	# Note that "defconfig" does not include FrameBuffer and graphics drivers.
	Write-Host "  Configuring"
	$exitCode = Execute "make" "ARCH=x86_64 defconfig" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Enable additional options.
	# "merge_config.sh" usage: $0 [OPTIONS] [CONFIG [...]]"
	#   -h    display this help text"
	#   -m    only merge the fragments, do not execute the make command"
	#   -n    use allnoconfig instead of alldefconfig"
	#   -r    list redundant entries when merging fragments"
	#   -y    make builtin have precedence over modules"
	#   -O    dir to put generated output files.  Consider setting \$KCONFIG_CONFIG instead."
	#   -s    strict mode. Fail if the fragment redefines any value."
	#   -Q    disable warning messages for overridden options."
	Write-Host "  Configuring additional options"
	$exitCode = Execute "./scripts/kconfig/merge_config.sh" "$projectRootDirectory/Hacks/linux-kernel-additional-config-options.txt" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Compiling the source code.
	Write-Host "  Compiling"
	$exitCode = Execute "make" "--silent ARCH=x86_64 --jobs=$makeJobs" $false 0
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

function BuildGrubPc {
	Write-Host "* Building Grub (PC)" -ForegroundColor Yellow

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
	$exitCode = Execute "./configure" "--disable-werror --target=x86_64 --with-platform=pc --enable-grub-mkfont --enable-efiemu --prefix ""$grubPcInstallDirectory""" $false 0
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
	Write-Host "  Installing into '$grubPcInstallDirectory'"
	$exitCode = Execute "make" "install" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Hack the "font.mod" file.
	# When I build Grub, I get a "font.mod" file that only display correctly on low resolution screen.
	# This is the case for both the "pc" and "efi" builds.
	# However, the file from my machine (Kubuntu 23.10) works - so this hack uses that file.
	Write-Host "  Hacking 'font.mod'"
	Write-Host "  When I build Grub, I get a "font.mod" file that only display correctly on low resolution screen." -ForegroundColor Cyan
	Write-Host "  This is the case for both the "pc" and "efi" builds." -ForegroundColor Cyan
	Write-Host "  However, the file from my machine (Kubuntu 23.10) works - so this hack uses that file." -ForegroundColor Cyan
	Copy-Item -Path "$grubPcInstallDirectory/lib/grub/i386-pc/font.mod" -Destination "$grubPcInstallDirectory/lib/grub/i386-pc/font.mod.original" -Force
	Copy-Item -Path "$projectRootDirectory/Hacks/font.mod" -Destination "$grubPcInstallDirectory/lib/grub/i386-pc" -Force

	# Remove temporary directory.
	Set-Location -Path "$currentDirectory"
	if (Test-Path "$tempDirectory" -PathType Container) {
		Write-Host "  Removing temp directory"
		Remove-Item -Recurse -Force "$tempDirectory"
	}
} # BuildGrubPc

function BuildGrubEfi {
	Write-Host "* Building Grub (EFI)" -ForegroundColor Yellow

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
	$exitCode = Execute "./configure" "--disable-werror --target=x86_64 --with-platform=efi --enable-grub-mkfont --prefix ""$grubEfiInstallDirectory""" $false 0
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
	Write-Host "  Installing into '$grubEfiInstallDirectory'"
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
} # BuildGrubEfi

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
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory/home/dotnet"  |  Out-Null
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

	# Install .NET Runtime and SDK.
	Write-Host "  Copying .NET Runtime and SDK"
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory$DotNetDiskDirectory"  |  Out-Null
	#$exitCode = Execute "tar" "--extract --file=""$projectDownloadsDirectory/$DotNetSdkDownloadFileName"" --directory=""$projectDiskDirectory$DotNetDiskDirectory""" $false 0
	$exitCode = Execute "tar" "--extract --file=""$projectDownloadsDirectory/$DotNetRuntimeDownloadFileName"" --directory=""$projectDiskDirectory$DotNetDiskDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}
	$exitCode = Execute "ln" "--force --symbolic --relative ""$projectDiskDirectory$DotNetDiskDirectory/dotnet"" ""$projectDiskDirectory/usr/bin/dotnet""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Install PowerShell.
	Write-Host "  Copying PowerShell"
    New-Item -ItemType Directory -Force -Path "$projectDiskDirectory$PowerShellDiskDirectory"  |  Out-Null
	$exitCode = Execute "tar" "--extract --file=""$projectDownloadsDirectory/$PowerShellDownloadFileName"" --directory=""$projectDiskDirectory$PowerShellDiskDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}
	$exitCode = Execute "ln" "--force --symbolic --relative ""$projectDiskDirectory$PowerShellDiskDirectory/pwsh"" ""$projectDiskDirectory/usr/bin/pwsh""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Extract DEB packages.
	# If we use "dkpg-deb" to extract the files directly to the desired destination, some files/directories that are
	# symbolic links are overwritten. This is awoided by extracting the files to a temporary directory, and then copying
	# the files to the desired destinatiion.
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

#	# Link to BASH.
#	$exitCode = Execute "ln" "--force --symbolic --relative ""$projectDiskDirectory/usr/bin/bash"" ""$projectDiskDirectory/usr/bin/sh""" $false 0
#	if ($exitCode -ne 0) {
#		EndProgram $exitCode
#	}

} # CreateDiskDirectory

function CopyFilesToDiskDirectory {
	Write-Host "* Copying additional files to disk directory" -ForegroundColor Yellow

	# Copy additional files.
	Write-Host "  Copying additional files"
	Copy-Item -Path "$projectCopyToDiskDirectory/*" -Destination "$projectDiskDirectory" -Force -Recurse  |  Out-Null

	# Copy additional files.
	Write-Host "  Copying 'root' user files"
	Copy-Item -Path "$projectCopyToDiskDirectoryRoot/*" -Destination "$projectDiskDirectory/home/root" -Force -Recurse  |  Out-Null

	# Copy additional files.
	Write-Host "  Copying 'dotnet' user files"
	Copy-Item -Path "$projectCopyToDiskDirectoryDotnet/*" -Destination "$projectDiskDirectory/home/dotnet" -Force -Recurse  |  Out-Null
} # CopyFilesToDiskDirectory

function SetRightsInDiskDirectory {
	Write-Host "* Setting rights on disk directory" -ForegroundColor Yellow

	# Set permissions.
	Write-Host "  All files"
	$exitCode = Execute "chmod" "--recursive 770 ""$projectDiskDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	$exitCode = Execute "chown" "--recursive 0:900 ""$projectDiskDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# For 'dotnet' user.
	Write-Host "  For 'dotnet' user"
	$exitCode = Execute "chmod" "--recursive 770 ""$projectDiskDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	$exitCode = Execute "chown" "--recursive 0:900 ""$projectDiskDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

# PowerShell files.
# /etc/powershell.config.json			$PSHOME
# /etc/Profile.ps1
#/opt/microsoft/powershell/7/powershell.config.json
#/data/users/rpc@rpc-scandinavia.dk/Profiles/Linux.kubuntu/.config/powershell
#/root/.config/powershell/Microsoft.PowerShell_profile.ps1
# .NET Runtime and SDK files.

} # SetRightsInDiskDirectory

function CreateDiskImage {
	Write-Host "* Creating disk image" -ForegroundColor Yellow

	# Create disk image.
	Set-Location -Path "$projectDiskDirectory"
	$exitCode = Execute "bash" "-c ""find . | cpio --create --format=newc  >  '$projectDiskImageFile'""" $false 0
	#$exitCode = Execute "cpio" "--create --format=newc --directory=""$projectDiskDirectory"" --file=""$projectDiskImageFile""" $false 0
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
    New-Item -ItemType Directory -Force -Path "$tempDirectory/boot/grub/locale"  |  Out-Null

	# Copy the Linux kernel file.
	Write-Host "  Copying Linux kernel"
	Copy-Item -Path "$projectBinariesDirectory/$kernelBinaryFileName" -Destination "$tempDirectory/boot" -Force

	# Copy the disk image file.
	Write-Host "  Copying disk image"
	Copy-Item -Path "$projectDiskImageFile" -Destination "$tempDirectory/boot" -Force

#	Copy-Item -Path "$grubPcInstallDirectory/lib/grub" -Destination "$tempDirectory/boot" -Force -Recurse
#	Copy-Item -Path "$grubPcInstallDirectory/share/locale/da" -Destination "$tempDirectory/boot/grub/locale" -Force

    # Grub configuration.
	Write-Host "  Creating '/boot/grub/grub.cfg'"
	$kernelFileName = [System.IO.Path]::GetFileName("$projectBinariesDirectory/$kernelBinaryFileName")
	$imageFileName = [System.IO.Path]::GetFileName("$projectDiskImageFile")
	$text = @"
insmod all_video
insmod gfxterm
insmod gettext
insmod font

set boot_once=true
set font=unicode
set lang=da_DK
set default=0
set timeout=30
set color_normal=yellow/blue
set menu_color_normal=black/white
set menu_color_highlight=light-gray/black
set gfxmode=1024x768

terminal_output gfxterm

menuentry 'RPC Linux .NET - PowerShell' --class os {
	insmod gzio
	insmod part_msdos
	linux /boot/$kernelFileName START_SHELL=pwsh $kernelParametersGrub
	initrd /boot/$imageFileName
}

menuentry 'RPC Linux .NET - Shell' --class os {
	insmod gzio
	insmod part_msdos
	linux /boot/$kernelFileName START_SHELL=sh $kernelParametersGrub
	initrd /boot/$imageFileName
}

menuentry "Reboot" {
	insmod reboot
	reboot
}

menuentry "Power Off" {
	insmod halt
	halt
}
"@
	$text  |  Out-File -FilePath "$tempDirectory/boot/grub/grub.cfg" -Force

	# Create the ISO file.
	Write-Host "  Creating ISO file"
	$exitCode = Execute "$grubPcInstallDirectory/bin/grub-mkrescue" "--verbose  --locale-directory=""$grubPcInstallDirectory/share/locale""  --locales=da  -output ""$projectDiskIsoFile""  ""$tempDirectory""" $false 0
	if ($exitCode -ne 0) {
		EndProgram $exitCode
	}

	# Remove temporary directory.
	if (Test-Path "$tempDirectory" -PathType Container) {
		Remove-Item -Recurse -Force "$tempDirectory"
	}
} # CreateISO

function RunDiskImage {
	param ([String]$startShell, [Boolean] $window)
	if (($startShell -ne "pwsh") -and ($startShell -ne "sh")) {
		Write-Host "  Error: Either specify 'pwsh' or 'sh' as start shell." -ForegroundColor Red
		EndProgram -1
	}

	Write-Host "* Running Linux kernel with disk image" -ForegroundColor Yellow

	if ($window -eq $true) {
		# Run virtual machine in its own window.
		Start-Process "qemu-system-x86_64" -Wait -PassThru -ArgumentList "-kernel ""$projectBinariesDirectory/$kernelBinaryFileName"" -initrd ""$projectDiskImageFile"" -append ""$kernelParametersQemu START_SHELL=$startShell"" -no-reboot -k da  -m size=8192 -nic user,model=virtio-net-pci"
	} else {
		# Run virtual machine in the current terminal, using serial TTY.
		# Use Start-Process directly, because we want I/O.
		Start-Process "qemu-system-x86_64" -Wait -PassThru -ArgumentList "-kernel ""$projectBinariesDirectory/$kernelBinaryFileName"" -initrd ""$projectDiskImageFile"" -append ""$kernelParametersQemu console=ttyS0 START_SHELL=$startShell"" -no-reboot -nographic -k da  -m size=8192 -nic user,model=virtio-net-pci"
	}

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
New-Item -ItemType Directory -Force -Path "$projectCopyToDiskDirectoryRoot"  |  Out-Null
New-Item -ItemType Directory -Force -Path "$projectCopyToDiskDirectoryDotNet"  |  Out-Null
New-Item -ItemType Directory -Force -Path "$grubPcInstallDirectory"  |  Out-Null
New-Item -ItemType Directory -Force -Path "$projectDiskDirectory"  |  Out-Null

# Run.
Write-Host "* Running RPC Linux .NET script" -ForegroundColor Yellow
Write-Host "  Using directory '$projectRootDirectory'"

#Download
#BuildLinuxKernel
#BuildToybox
#BuildBusybox
#BuildGrubPc
#BuildGrubEfi
#CreateDiskDirectory
#CopyFilesToDiskDirectory
#SetRightsInDiskDirectory
#CreateDiskImage
#CreateISO
#RunDiskImage "sh" $false
EndProgram 0
