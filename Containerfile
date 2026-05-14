FROM ghcr.io/bootcrew/arch-bootc:latest

### --- System Packages --- ###

RUN pacman -Syu --noconfirm

# Use LTS kernel (ComposeFS broken on 6.19 and 7.0)
RUN rm -rf /usr/lib/modules
RUN pacman -S --noconfirm linux-lts linux-lts-headers
RUN pacman -R --noconfirm linux

# Install sudo for permission escalation
RUN pacman -S --noconfirm sudo

# Greeter and window manager (sway + auto tiling)
RUN pacman -S --noconfirm greetd greetd-gtkgreet sway swaybg swayidle swaylock xorg-xwayland autotiling-rs waybar

# Launcher
RUN pacman -S --noconfirm rofi

# Notification daemon
RUN pacman -S --noconfirm mako

# Polkit
RUN pacman -S --noconfirm polkit lxqt-policykit

# Other utilities
RUN pacman -S --noconfirm grim slurp nwg-look fastfetch git just podman

# Fonts
RUN pacman -S --noconfirm noto-fonts noto-fonts-extra noto-fonts-cjk noto-fonts-emoji unicode-emoji

# Audio
RUN pacman -S --noconfirm pavucontrol wireplumber pipewire pamixer

# Network stuff
RUN pacman -S --noconfirm network-manager-applet bluez bluez-tools blueman

# Terminal
RUN pacman -S --noconfirm kitty zsh

# Clipboard stuff
RUN pacman -S --noconfirm cliphist wl-clipboard wtype

# General desktop stuff - editor, file manager, etc
RUN pacman -S --noconfirm helix thunar thunar-archive-plugin file-roller 7zip bzip3 unrar unzip rpmextract dpkg gnome-disk-utility

# Flatpak stuff
RUN pacman -S --noconfirm flatpak bazaar

### --- AUR Packages --- ###

# Enable Chaotic AUR repo
RUN pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
RUN pacman-key --init && pacman-key --lsign-key 3056513887B78AEB
RUN pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm
RUN pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm
RUN echo -e '[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf

# Sync packages again
RUN pacman -Syu --noconfirm

# AUR packages
# wlogout - nice logout menu
# still - freeze a wayland compositor (used for screenshot tool)
# swaywsr - sway workspace renamer
RUN pacman -S --noconfirm chaotic-aur/wlogout

### --- Finalise Image --- ###

# Edit sway config to change default menu and terminal
# maybe I should have it import (at least parts of) my config later? probably just put in ./system_files
RUN sed -i '/set $term/c\set $term kitty' /etc/sway/config && \
  sed -i '/set $menu/c\set $menu rofi -show dmenu' /etc/sway/config
  
# Copy necessary files onto the image (e.g. systemd service setup)
COPY ./system_files /

# Setup systemd services
RUN systemctl preset-all && systemctl preset-all --global

# Regenerate initramfs
RUN mkdir -p /var/tmp
RUN mkdir -p /usr/lib/dracut/dracut.conf.d/
RUN mkdir -p /var/roothome
RUN printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-fix-bootc-module.conf
RUN printf 'reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=" bootc "' | tee "/usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-container-build.conf"
RUN dracut --force "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)/initramfs.img"

# Fix PAM bullshit
RUN sed -i 's/.*pam_shells.*//g' /etc/pam.d/system-login
