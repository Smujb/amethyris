image_name := env("BUILD_IMAGE_NAME", "amethyris")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", ".")
filesystem := env("BUILD_FILESYSTEM", "ext4")
selinux := env("BUILD_SELINUX", "true")

options := if selinux == "true" { "-v /var/lib/containers:/var/lib/containers:Z -v /etc/containers:/etc/containers:Z -v /sys/fs/selinux:/sys/fs/selinux --security-opt label=type:unconfined_t" } else { "-v /var/lib/containers:/var/lib/containers -v /etc/containers:/etc/containers" }
container_runtime := env("CONTAINER_RUNTIME", `command -v podman >/dev/null 2>&1 && echo podman || echo docker`)

build *ARGS:
    sudo {{container_runtime}} build -t "{{image_name}}:{{image_tag}}" . {{ARGS}}

bootc $image_name=image_name $image_tag=image_tag *ARGS:
    sudo {{container_runtime}} run \
        --rm --privileged --pid=host \
        -it \
        {{options}} \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{base_dir}}:/data" \
        "${image_name}:${image_tag}" bootc {{ARGS}}

disk-image $image_name=image_name $image_tag=image_tag $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    if [ ! -e "${base_dir}/bootable.img" ] ; then
        fallocate -l 20G "${base_dir}/bootable.img"
    fi
    just bootc $image_name $image_tag install to-disk --composefs-backend --via-loopback /data/bootable.img --filesystem "${filesystem}" --wipe --bootloader systemd

rechunk $image_name=image_name:
    #!/usr/bin/env bash
    export CHUNKAH_CONFIG_STR="$(sudo podman inspect "${image_name}")"
    sudo podman run --rm "--mount=type=image,src=${image_name},target=/chunkah" -e CHUNKAH_CONFIG_STR quay.io/coreos/chunkah build --label ostree.bootable=1 --compressed --max-layers 128 | \
        sudo podman load | \
        sort -n | \
        head -n1 | \
        cut -d, -f2 | \
        cut -d: -f3 | \
        xargs -I{} sudo podman tag {} "${image_name}"

lint:
    podman run --rm -it --entrypoint=bootc localhost/${image_name}:{image_tag} container lint

explore-image *ARGS:
    just build {{ARGS}}
    sudo podman run --rm -it "{{image_name}}:{{image_tag}}" bash
