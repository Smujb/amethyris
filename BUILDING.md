# Building Amethyris

The Justfile contains just recipes which make building this project easier.

Any command with `[sudo]` before it requires privelige escalation, but sudo itself is not necessary.

## bootc

- `just build-bootc` - build an OCI image for use with bootc
- `[sudo] just load` - load the image into containers-storage
- `[sudo] just generate-image-bootc` - generate a .img file for the VM.

This .img file can be booted in a VM or installed onto a disk using `dd`.

## sysupdate

- `just build-sysupdate` - build the .raw files
- `just apply-sysupdate` - run the output through systemd-sysupdate to stage it for the next boot
- `just vm-sysupdate` - run the generated .raw in a vm instead; uses [vmbuddy](https://github.com/tulilirockz/vmbuddy)
- `just resize-raw-sysupdate` -resize the generated .raw file so it can be used as a live iso
