# Amethyris (Amethyst Iris) - Arch Linux bootc with swaywm

> [!WARNING]
> This is currently in the very early stages of development and things are likely to change significantly. This includes what utilities are included by default. Right now this is mainly only intended for my personal use, though I plan to slowly clean it up and make it easier to maintain more broadly.

This is an opinionated bootc image made using [mkosi](https://github.com/systemd/mkosi/tree/main), specifically using [this template](https://github.com/Smujb/mkosi-arch-boot). A relatively lightweight setup with the sway window manager. I use this alongside [my dotfiles](https://github.com/Smujb/dotfiles).

## Overview

Much like upstream Arch, Amethyris aims to push out packages quickly with minimal additional patches so your system is always up-to-date and shipping software that functions in line with the original developers' intentions. Images build daily and little is included on the image that could easily be obtained some other way (for example, brew or flatpak). An emphasis is placed on "do-it-yourself"; only minimal dotfiles are included and all are free to be modified.

Currently, there is no image for the Nvidia proprietary drivers or for any window manager other than sway (the open source Nouveau / NVK stack is included instead for Nvidia graphics cards). I am willing to provide options for these things only if others are willing to commit to maintaining them long-term. Alternatively, you could fork this repository and make it use whatever you want and maintain it entirely yourself.

## Bootc

Image updates are deployed using bootc. Instead of updating individual packages (ideally simultaneously!) using pacman, bootc will load an image that was built from scratch with the new versions of all the baseline software and deploy it to your system. This has pros and cons, but generally results in a more stable system long-term that requires less maintenance. Unlike regular Arch for example, updating after leaving your laptop unused for 2 months won't result in "manual intervention is required" and the risk of a broken system if you mess up. The old image will simply be seamlessly swapped out with the new when you next reboot. On the flip side, you can't simply `pacman -S [app]` but don't worry - there are still plenty of ways to install things.

## Installing Software

The default GUI file manager is Thunar. A few others such as Dolphin are available as flatpaks.

Feel free to grab your favourite editor from brew. Nano and vim are included on the image; other terminal-based editors like neovim or helix or micro are easy enough to get. For GUI-based editors see [Universal Blue's homebrew tap](https://github.com/ublue-os/homebrew-tap/) which has VS Code and Jetbrains Toolbox among others. Other editors may need to be installed more manually.

The default terminal is foot. Most terminals work fine as an AppImage or even a flatpak, and some also offer support for a local installation in `~/.local`.

Other apps should be installed using brew, flatpak or a tarball. If none of these are suitable, you can try distrobox which is also included on the image, or you can try overlaying them with the script below or make a custom image. While I am willing to entertain suggestions for new default utilities, most are likely to be rejected.

### Package Layering?

Possible using [this script](https://github.com/Smujb/bootc-tools/blob/main/build-overlay-ext). Note that you will need to define all the packages you wish to layer in a shell script and pass it to the program, and you will need to rerun it every time you wish to either add/remove a package from the overlay or after calling bootc update (to ensure a new overlay exists for the new deployment).

This relies on the Arch Linux Archive. As such, no binary repos other than the official (core, extra, multilib) should be used on the image.

### AUR?

Regular AUR should in theory work using the above method as long as the PKGBUILDs are built on the image. However, due to this being a community maintained repository, there is no guarantee that a PKGBUILD will work on anything but the absolute latest package list for Arch Linux. Additionally, installing AUR packages using a helper in an automated fashion is a terrible idea.

If you wish to use packages not present on the official Arch repos, I recommend manitaining your own PKGBUILDs. If you wish to use the AUR you can get them from there and manually update using git. Check the PKGBUILD not just for malware but for requring dependencies or versions of dependencies not currently available.
