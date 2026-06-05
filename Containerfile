### --- build some binaries from source --- ###

# For building additional packages
FROM docker.io/library/archlinux as archcontainer

RUN pacman -Syu --noconfirm

# Build still
RUN pacman -S --noconfirm git gcc pkg-config meson pixman wayland wayland-protocols && git clone https://github.com/faergeek/still.git
WORKDIR /still
RUN meson setup --buildtype release build && ninja -C build

WORKDIR /

# Build swaywsr
RUN pacman -S --noconfirm cargo &&  git clone https://github.com/pedroscaff/swaywsr.git
WORKDIR /swaywsr
RUN cargo build --release

### --- main image build --- ###

FROM ghcr.io/bootcrew/arch-bootc:latest

# Homebrew
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /

### --- System Packages --- ###

# Copy binaries built earlier
COPY --from=archcontainer /swaywsr/target/release/swaywsr /usr/bin/swaywsr
COPY --from=archcontainer /still/build/still /usr/bin/still

# Enable multilib repo for 32 bit driver support
RUN echo -e '[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf

RUN pacman -Syu --noconfirm

# Insure headers and firmware are properly installed
RUN pacman -S --noconfirm linux-firmware linux-headers

# Install GPU drivers
RUN pacman -S --noconfirm mesa mesa-utils libva-mesa-driver lib32-mesa \
    vulkan-radeon lib32-vulkan-radeon \
    vulkan-intel lib32-vulkan-intel \
    vulkan-nouveau lib32-vulkan-nouveau \
    vulkan-tools

# Install sudo for permission escalation
RUN pacman -S --noconfirm sudo

# Greeter and window manager (sway + uwsm + auto tiling)
RUN pacman -S --noconfirm greetd greetd-gtkgreet sway swaybg swayidle swaylock wlr-randr uwsm xorg-xwayland autotiling-rs waybar \
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr

# Launcher
RUN pacman -S --noconfirm rofi

# Notification daemon
RUN pacman -S --noconfirm mako

# Polkit & secret service stuff
RUN pacman -S --noconfirm polkit lxqt-policykit gnome-keyring

# Other utilities and dependencies
RUN pacman -S --noconfirm grim slurp nwg-look fastfetch git just podman less perl man man-db man-pages mokutil zram-generator

# Fonts
RUN pacman -S --noconfirm noto-fonts noto-fonts-extra noto-fonts-cjk noto-fonts-emoji unicode-emoji otf-font-awesome

# Audio
RUN pacman -S --noconfirm pavucontrol wireplumber pipewire pamixer pipewire-pulse

# Network stuff
RUN pacman -S --noconfirm network-manager-applet inetutils net-tools bluez bluez-utils bluez-tools blueman usbutils

# Terminal
RUN pacman -S --noconfirm kitty zsh distrobox

# Clipboard stuff
RUN pacman -S --noconfirm cliphist wl-clipboard wtype

# General desktop stuff - editor, file manager, etc
RUN pacman -S --noconfirm helix thunar thunar-archive-plugin gvfs file-roller 7zip bzip3 unrar unzip rpmextract dpkg gnome-disk-utility

# Flatpak stuff
RUN pacman -S --noconfirm flatpak bazaar

# GAMER stuff
RUN pacman -S --noconfirm steam mangohud gamescope switcheroo-control

# Scopebuddy
RUN curl -Lo /usr/bin/scb https://raw.githubusercontent.com/HikariKnight/ScopeBuddy/refs/heads/main/bin/scopebuddy &&  chmod +x /usr/bin/scb

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
# obs-vkcapture-git - vulkan layer for OBS game capture on native applications
RUN pacman -S --noconfirm chaotic-aur/wlogout chaotic-aur/obs-vkcapture-git

### --- Finalise Image --- ###

# Copy necessary files onto the image (e.g. systemd service setup)
COPY ./system_files /

# Ensure interactive bash shells have the same workarounds as zsh
RUN echo -e 'source /etc/profile.d/brew.sh' | tee -a /etc/bash.bashrc

RUN curl https://raw.githubusercontent.com/sentriz/cliphist/refs/heads/master/contrib/cliphist-rofi-img > /usr/bin/cliphist-rofi-img && chmod +x /usr/bin/cliphist-rofi-img

# Setup systemd services
RUN systemctl preset-all && systemctl preset-all --global

# Fix PAM bullshit (pam_shells breaks systemd-homed user auth)
RUN sed -i 's/.*pam_shells.*//g' /etc/pam.d/system-login

# Add gnome keyring PAM support for both greetd and tty login
RUN echo -e 'auth\toptional\tpam_gnome_keyring.so\nsession\toptional\tpam_gnome_keyring.so auto_start' | tee -a /etc/pam.d/system-login

# Run helix when the user types hx, as intended upstream
RUN sudo ln -s $(which helix) /usr/bin/hx

# Fix rootless podman
RUN setcap -r /usr/bin/newuidmap && setcap -r /usr/bin/newgidmap && chmod u+s /usr/bin/newuidmap /usr/bin/newgidmap


### --- OS Release Info --- ###

# Variables for image identification
ARG IMAGE_NAME="Amethyris"
ARG HOSTNAME="amethyris"
ARG HOME_URL="https://github.com/Smujb/amethyris"
ARG SUPPORT_URL="https://github.com/Smujb/amethyris"
ARG ID="amethyris"
ARG ID_LIKE="arch"
ARG BUILD_ID="rolling"
ARG LOGO=archlinux-logo

# Ensure our image identifies itself correctly
RUN cat > /usr/lib/os-release <<EOF
NAME=$IMAGE_NAME
ID=$ID
ID_LIKE=$ID_LIKE
BUILD_ID=$BUILD_ID
PRETTY_NAME=$IMAGE_NAME
HOME_URL=$HOME_URL
SUPPORT_URL=$SUPPORT_URL
LOGO=$LOGO
DEFAULT_HOSTNAME=$HOSTNAME
EOF

# Copy the files to /etc
RUN cp /usr/lib/os-release /etc/os-release


### --- Regenerate Initramfs --- ###

RUN mkdir -p /var/tmp /var/roothome
RUN dracut --force "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)/initramfs.img"
