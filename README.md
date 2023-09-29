# RPC Linux .NET

This project is my attempt to create a small Linux system that is able to execute the .NET runtime and non graphical .NET programs.

Currently the build includes:

* Linux kernel
* Toybox
* Busybox
* Midnight Commander
* Grub

Plus dependencies required to execute the above and the .NET runtime. But in the end, it should be possible to exclude Toybox, Busybox and Midnight Commander and run a .NET application as `INIT`.

## Architecture

At this time, the build system and the Linux system is only for the `x86_64` architecture. If and when this project succeeds, it could be an option to extend the script and build for `arm64` or other architectures.

## Debian

I am a Debian guy, so I run Debian Linux on my servers and some Debian derivative on my virtual workstation. Currently I am running Kubuntu 23.10.

The entire script completed in about 30 minutes on my "not so fast" machine.

## Known bugs

### User IO
Something is missing for the screen and keyboard to function properly. Midnight Commander, and a .NET test application, can't write in colours and keyboard mappings are wrong.

## Contact

Please feel free to contact me, if you have suggestions to how the system can be improved.
