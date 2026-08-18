image_name := env("BUILD_IMAGE_NAME", "amethyris")
image := env("IMAGE_FULL", "amethyris:latest")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", ".")
filesystem := env("BUILD_FILESYSTEM", "ext4")
just := just_executable()
profiles := env("BUILD_PROFILES", "")

[private]
default:
    @{{ just }} --list

[script]
_check-root:
    #!/usr/bin/env bash
    if [[ $EUID -ne 0 ]]; then
       echo "This script must be run as root" 
       exit 1
    fi

# Build .raw files for systemd-sysupdate
[group('sysupdate')]
build-sysupdate $profiles=profiles:
    #!/usr/bin/env bash
    
    for profile in {{profiles}}; do
        args="$args --profile $profile"
    done

    mkosi build -B -ff sysupdate --profile=sysupdate ${args}

[group('sysupdate')]
_find-raw-sysupdate:
    find "{{ base_dir }}/mkosi.output" -maxdepth 1 -iname "amethyris*x86-64.raw"

# Open the generated .raw in a vm
[group('sysupdate')]
vm-sysupdate:
    dd if=/dev/zero of=$({{ just }} _find-raw-sysupdate) bs=1G count=0 seek=50    
    vmbuddy $({{ just }} _find-raw-sysupdate)

# Apply and stage the update for next boot
[group('sysupdate')]
apply-sysupdate:
    mkosi sysupdate -- update

# Build and then apply
[group('sysupdate')]
build-apply-sysupdate $profiles=profiles:
    {{ just }} build-sysupdate {{profiles}}
    {{ just }} apply-sysupdate

# Resize .raw file for writing to a live iso or system
[group('sysupdate')]
resize-raw-sysupdate:
    dd if=/dev/zero of=$({{ just }} _find-raw-sysupdate) bs=1G count=0 seek=25

# Build an OCI image for use with bootc
[group('bootc')]
build-bootc $profiles=profiles:
    #!/usr/bin/env bash
    for profile in {{profiles}}; do
        args="$args --profile $profile"
    done

    mkosi -B --debug --profile=bootc ${args}

# Lint the bootc image
[group('bootc')]
lint:
    podman run --rm -it --entrypoint=bootc {{image}} container lint

# Load image into containers-storage
[group('bootc')]
load:
    #!/usr/bin/env bash
    set -x
    podman load -i "$(find '{{ base_dir }}/mkosi.output' -maxdepth 1 -type d -printf "%T@ ,%p\n" -iname "amethyris*x86-64" | sort -n | head -n1 | cut -d, -f2)" -q | cut -d: -f3 | xargs -I{} podman tag {} {{image}}

[group('bootc')]
_bootc *ARGS:
    #!/usr/bin/env bash
    set -eoux pipefail

    BOOTC_INSTALL_OPTIONS=()
    BOOTC_INSTALL_OPTIONS+=("-v" "/var/lib/containers:/var/lib/containers" "-v" "/etc/containers:/etc/containers")

    if [[ -d /sys/fs/selinux ]]; then
      BOOTC_INSTALL_OPTIONS+=("-v" "/sys/fs/selinux:/sys/fs/selinux" "--security-opt" "label=type:unconfined_t")
    fi

    podman run \
        --rm --privileged --pid=host \
        -it \
        "${BOOTC_INSTALL_OPTIONS[@]}" \
        -v /dev:/dev \
        -v "${BUILD_BASE_DIR:-.}:/data" \
        {{image}} bootc {{ ARGS }}

# Generate a bootable .img file with the system installed
[group('bootc')]
generate-image-bootc $filesystem=filesystem:
    #!/usr/bin/env bash
    set -e
    {{ just }} _check-root
    if [ ! -e "{{ base_dir }}/bootable.img" ] ; then
        fallocate -l 20G "{{ base_dir }}/bootable.img"
    fi
    {{ just }} _bootc install to-disk --composefs-backend --via-loopback /data/bootable.img --filesystem "${filesystem}" --wipe --bootloader systemd

# Fix "cannot apply additional memory protection after relocation" errors building the image on systems with SELinux.
[group('bootc')]
fix-selinux-container-permissions:
    #!/usr/bin/env bash
    set -e
    {{ just }} _check-root
    restorecon -RFv /var/lib/containers/storage

# Run a shell in the container
[group('bootc')]
run-shell-bootc:
    podman run \
        --rm --privileged --pid=host \
        -it \
        -v /sys/fs/selinux:/sys/fs/selinux \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{ base_dir }}:/data" \
        --security-opt label=type:unconfined_t \
        "{{image}}" bash

# Rechunk the final image with Chunkah
[group('bootc')]
rechunk: 
    #!/usr/bin/env bash
    IMG="{{image}}"
    export CHUNKAH_CONFIG_STR="$(podman inspect $IMG)"
    podman run --rm --mount=type=image,src=$IMG,dest=/chunkah \
        -e CHUNKAH_CONFIG_STR quay.io/coreos/chunkah build \
        --label containers.bootc=1 \
        --compressed --max-layers 128 \
        -t $IMG | podman load

# Clear mkosi.cache and mkosi.tools for a cleaner rebuild
clear-cache:
    set -e
    {{ just }} _check-root
    rm -r mkosi.tools/ mkosi.cache/
