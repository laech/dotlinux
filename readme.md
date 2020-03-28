Installs a minimal Arch Linux system on an encrypted ZFS root, with
EFISTUB booting directly from the kernal.

Scripts:
* **setup-install-partition.sh**: root script to partition a disk and
  executes the below scripts.
* **setup-install.sh**: install base system and execute below script.
* **setup.sh**: setups a newly installed system.

shellx64_v1.efi is v1 UEFI shell copied from Arch Linux live image.
