# Building Amethyris

The Justfile contains just recipes which make building this project easier.

Any command with `[sudo]` before it requires privelige escalation, but sudo itself is not necessary.

## bootc

### Building for testing in a VM

- `just build-bootc` - build an OCI image for use with bootc
- `[sudo] just load` - load the image into containers-storage
- `[sudo] just generate-image-bootc` - generate a .img file for the VM.

Note that rechunking is not necessary for purely testing, and linting is mainly included to ensure that CI builds will fail if they produce a broken bootc image.

This .img file can be booted in a VM or installed onto a disk using `dd` in order to install the system in the first place.

### Building to rebase to locally

- `just build-bootc`
- `just load`
- (optional) `just rechunk` - generally doesn't save time overall when building locally but you can do it if you like
- `just lint` - check the generated image is valid
- [first run] `[sudo] bootc switch bootc switch --transport containers-storage localhost/amethyris:latest` - switch to the locally built image
- [already on localhost/amethyris:latest] `[sudo] bootc update` - update to the latest verison of the locally built image

## sysupdate

The sysupdate backend requires building with disk encryption and secure boot support. You will need to provide your own keys. If you 

### Building for testing in a VM

- `just build-sysupdate` - build the .raw files
- `just vm-sysupdate` - run the generated .raw in a vm instead; uses [vmbuddy](https://github.com/tulilirockz/vmbuddy)

### Building to install using a removable drive

- `just build-sysupdate`
- `just resize-raw-sysupdate` - resize the generated .raw file so it can be used as a live iso
- [write the big .raw file ending in {arch}.raw to a bootable storage medium like a usb drive]
- [booted into live environment] `[sudo] systemd-repart --dry-run=no --empty=force --defer-partitions=swap,root,home`

> [!WARNING]
> Make sure you build the system and update it using the same set of secure boot keys. Any time you change the keys the OS is signed with you will need to enter a recovery key or password in order to unlock your encrypted root as the TPM2 unlock will be invalid.
> If using secure boot you will need to temporarily disable it, boot up your system and then re-enroll the new keys. You will also need to reinstall the bootloader after booting into the new system to ensure it is signed with the new keys.

### Building to update locally

- `just build-sysupdate`
- `just apply-sysupdate` - apply the update in `mkosi.output` using `systemd-sysupdate`

or

- `just build-apply-sysupdate` - run both build and apply in one command

### Setting up secure boot

The recommended method for secure boot on Amethyris is using the Microsoft-signed `shim` and MOKs.

Firstly, ensure you are successfully booted (likely with secure boot disabled) into a version of Amethyris signed with keys from your local installation - including the bootloader. `mkosi genkey` will create `mkosi.key` and `mkosi.crt` by default and you will need a `.key` and `.crt` file for this.

Run the following command:

`openssl x509 -outform DER -in mkosi.crt -out mkosi.cer`

If your `.crt` file is named differently, adjust the command as needed.

Then run:

`[sudo] mokutil --import mkosi.cer`

Enter a one-time password and confirm it. Then reboot + enable secure boot and you should see a blue interface with the options "Continue boot" and "Enroll MOK" among others while the system is loading. Select "Enroll MOK" using the arrow keys and enter and you will be prompted for this password. After entering it correctly, you will now have a functional secure boot setup!

### Encryption recovery keys

Enroll a recovery key immediately after booting into your system with `[sudo] systemd-cryptenroll /dev/[disk] --recovery-key`.

Where `/dev/[disk]` is the name of the disk with the root partition. This can be found by running `lsblk`. Store it in a safe place such as a password manager, but ensure you have access to it without needing to boot your PC.

To re-enable TPM2 auto unlock after using the backup password to log in, run `[sudo] systemd-cryptenroll /dev/[disk] --wipe-slot=tpm2 --tpm2-device=auto`. Reinstall the bootloader with `[sudo] bootctl install` to ensure it is signed with the same keys.
