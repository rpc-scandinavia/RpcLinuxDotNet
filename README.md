# RPC Linux .NET
This project is my attempt to create a small Linux system that is able to execute the .NET runtime and non graphical .NET programs.

Currently the build includes:

* Linux kernel (source)
* Toybox (source)
* Busybox (source)
* Midnight Commander (packages)
* Grub (packages)
* .NET Runtime and SDK (package)
* PowerShell (package)

Plus dependencies required to execute the above.

### Init
The system boots like this.

<div align="center">

|                                   | BOOT               |                                   |
|----------------------------------:|:------------------:|:----------------------------------|
|                                   | Grub               |                                   |
|                                   | 🡇                 |                                   |
|                                   | Linux kernel       |                                   |
|                                   | 🡇                 |                                   |
|                                   | `init.sh`          |                                   |
| 🡿                                 |                    | 🡾                                 |
| PowerShell                        |                    | Bash                              |
| `init-powershell.ps1`             |                    | `init-shell.sh`                   |
|___________________________________|____________________|___________________________________|

</div>

It is not possible to run a .NET application as `INIT`, because the runtime is dynamically linked and it requires environment variables being set. In theory you could pass environment variables in Grub as parameters to the Linux kernel, but it has a limit, and some binaries are called in the `init.sh` script.

## Architecture
At this time, the build system and the Linux system is only for the `x86_64` architecture. If and when this project succeeds, it could be an option to extend the script and build for `arm64` or other architectures.

## Debian
I am a Debian guy, so I run Debian Linux on my servers and some Debian derivative on my virtual workstation. Currently I am running Kubuntu 23.10.

The entire script completed in about 30 minutes on my "not so fast" machine.

## Known bugs
There is a issue with the terminal and key mapping in **PowerShell** and **Midnight Commander**. In PowerShell it is primary the `backspace` key that don't work, so entered text can't be deleted and because PowerShell itself tries to delete entered text, to change colour, all entered text is multiplied letter by letter. In Midnight Commander many keys are wrong, and the arrow keys do not work.

My own managed test application, also has problems getting the terminal size, and moving the cursor.

I get a not working `font.mod` when I build **Grub**. Both the **pc** and **efi** versions causes the Grub menu to will with `@`-like characters, in higher resolutions.

Other **big** issued, I think is fixed, is automatically building the Linux kernel with the Framebuffer enabled. The terminal is limited to text-mode without the Framebuffer, and I want high resolution already in Grum, continuieng into the terminal.

### User IO
Something is missing for the screen and keyboard to function properly. Midnight Commander, and a .NET test application, can't write in colours and keyboard mappings are wrong.

## Contact
Please feel free to contact me, if you have suggestions to how the system can be improved.
