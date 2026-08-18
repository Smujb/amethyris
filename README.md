# Amethyris (Amethyst Iris) - Image-based Arch Linux with swaywm

> [!WARNING]
> This is currently in the very early stages of development and things are likely to change significantly. This includes what utilities are included by default. Right now this is mainly only intended for my personal use, though I plan to slowly clean it up and make it easier to maintain more broadly.

This is an opinionated bootc image made using [mkosi](https://github.com/systemd/mkosi/tree/main), specifically using [this template](https://github.com/Smujb/mkosi-arch-bootc). A relatively lightweight setup with the sway window manager. I use this alongside [my dotfiles](https://github.com/Smujb/dotfiles).

## Overview

Much like upstream Arch, Amethyris aims to push out packages quickly with minimal additional patches so your system is always up-to-date and shipping software that functions in line with the original developers' intentions. Images build daily and little is included on the image that could easily be obtained some other way (for example, brew or flatpak). An emphasis is placed on "do-it-yourself"; only minimal dotfiles are included and all are free to be modified.

Currently, there is no image for the Nvidia proprietary drivers or for any window manager other than sway (the open source Nouveau / NVK stack is included instead for Nvidia graphics cards). I am willing to provide options for these things only if others are willing to commit to maintaining them long-term. Alternatively, you could fork this repository and make it use whatever you want and maintain it entirely yourself.

## Image-based

Updates are applied by swapping full system images in and out, instead of upgrading individual packages. This tends to require less maintenance, especially when updating using the remote packages for bootc provided at `ghcr.io/smujb/amethyris`. Additionally, /usr won't get filled up by untracked files which are not considered to be part of any package, and replacing orphaned packages is straightforward as you don't have to uninstall what was there before. And lastly, you can rollback from the bootloader (systemd-boot) at any time so if you have a bad update you can just stay on the last version for a bit and perhaps pin it.

The two backends available right now are: bootc (both remote and local, but ideally remote) and systemd-sysupdate (currently only local)

When running a local installation you can add your own packages and scripts in mkosi.local.conf or mkosi.local/ which are untracked by git.

### bootc

[Bootc](https://bootc.dev/bootc/) is a Red Hat technology designed for booting OCI containers (docker/podman) on bare metal or virtual machines. Amethyris uses the (currently "experimental") composefs-native backend which is not built on top of rpm or dated technology like [ostree](https://ostreedev.github.io/ostree/introduction/).

Installation currently requires either rebasing from another composefs-native bootc system (`bootc switch ghcr.io/smujb/amethyris:latest`) or using dd to write a generated bootable.img file onto the disk and then resizing the system partition to fill the remaining space. Updating is as simple as running `bootc update`. Note that it is possible to run this locally (build an image, load it into podman, then run `sudo bootc switch --transport containers-storage localhost/amethyris:latest`) but if you want to run this image locally I highly suggest the sysupdate backend.

### systemd-sysupdate

Sysupdate is a technology built by systemd for swapping out .raw disk image files to use in an A/B update system. The scope of what it can do is vast but amethyris specifically implements a very similar concept to [particleos](https://github.com/systemd/particleos) - local, customizeable and secure. Amethyris aims to address some of the ux papercuts ParticleOS has while maintaining the secure and stable baseline it operates on.

Installation can be done either by generating a .raw file and writing that directly to a disk, or writing it to a USB drive and running `systemd-repart --dry-run=no --empty=force --defer-partitions=swap,root,home /dev/<drive>` on the live system. Note that the .raw file created will be too small to run systemd-repart; resize it using `just resize-raw-sysupdate` first (this is not an issue during the installation from USB, just the initial writing of the .raw file).

## Installing Software

The default GUI file manager is Thunar. A few others such as Dolphin are available as flatpaks.

Feel free to grab your favourite editor from brew. Nano and vim are included on the image; other terminal-based editors like neovim or helix or micro are easy enough to get. For GUI-based editors see [Universal Blue's homebrew tap](https://github.com/ublue-os/homebrew-tap/) which has VS Code and Jetbrains Toolbox among others. Other editors may need to be installed more manually.

The default terminal is foot. Most terminals work fine as an AppImage or even a flatpak, and some also offer support for a local installation in `~/.local`.

Other apps should be installed using brew, flatpak or a tarball. If none of these are suitable, you can try distrobox which is also included on the image, or you can try overlaying them with the script below or make a custom image. While I am willing to entertain suggestions for new default utilities, most are likely to be rejected.

### Package Layering?

Note: currently only possible when using bootc - however largely unnecessary when running sysupdate locally.

Possible using [this script](https://github.com/Smujb/bootc-tools/blob/main/build-overlay-ext). Note that you will need to define all the packages you wish to layer in a shell script and pass it to the program, and you will need to rerun it every time you wish to either add/remove a package from the overlay or after calling bootc update (to ensure a new overlay exists for the new deployment).

This relies on the Arch Linux Archive. As such, no binary repos other than the official (core, extra, multilib) should be used on the image.

### AUR?

Regular AUR should in theory work using the above method as long as the PKGBUILDs are built on the image. However, due to this being a community maintained repository, there is no guarantee that a PKGBUILD will work on anything but the absolute latest package list for Arch Linux. Additionally, installing AUR packages using a helper in an automated fashion is a terrible idea.

If you wish to use packages not present on the official Arch repos, I recommend manitaining your own PKGBUILDs. If you wish to use the AUR you can get them from there and manually update using git. Check the PKGBUILD not just for malware but for requring dependencies or versions of dependencies not currently available.
