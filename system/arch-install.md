# Arch install with LUKS (as configured on the X1 Extreme, for reproducing on a new machine)

Documented 2026-09-02 from the running system. Scheme: **LUKS-on-partition → LVM → btrfs**,
with unencrypted `/boot` so GRUB never has to unlock anything (one passphrase prompt,
in early userspace).

## Disk layout (1 TB NVMe)

| Partition | Size | FS | Mount | Notes |
|---|---|---|---|---|
| `p1` | 1G | vfat | `/efi` | ESP |
| `p2` | 5G | ext4 | `/boot` | unencrypted — kernels + initramfs |
| `p3` | rest | LUKS | — | opened as `cryptlvm` |

Inside LUKS: LVM volume group **`vg0`**, all logical volumes btrfs (no subvolumes —
plain btrfs on each LV):

| LV | Size (old) | Mount |
|---|---|---|
| `vg0-root` | 100G | `/` |
| `vg0-home` | 400G | `/home` |
| `vg0-lib`  | rest (~448G) | `/var/lib` (docker images etc. kept off root) |

No swap partition/LV — no hibernate. No `/etc/crypttab` entries (the single LUKS device
is opened by the initramfs `encrypt` hook, not by systemd later).

## Install steps (from the Arch ISO)

```
sgdisk -Z /dev/nvme0n1
sgdisk -n1:0:+1G  -t1:ef00 /dev/nvme0n1   # ESP
sgdisk -n2:0:+5G  -t2:8300 /dev/nvme0n1   # /boot
sgdisk -n3:0:0    -t3:8309 /dev/nvme0n1   # LUKS

cryptsetup luksFormat /dev/nvme0n1p3       # LUKS2 defaults are fine
cryptsetup open /dev/nvme0n1p3 cryptlvm

pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L 100G vg0 -n root
lvcreate -L 400G vg0 -n home               # scale to taste on a bigger/smaller disk
lvcreate -l 100%FREE vg0 -n lib

mkfs.fat  -F32 /dev/nvme0n1p1
mkfs.ext4      /dev/nvme0n1p2
mkfs.btrfs /dev/vg0/root
mkfs.btrfs /dev/vg0/home
mkfs.btrfs /dev/vg0/lib

mount /dev/vg0/root /mnt
mkdir -p /mnt/{efi,boot,home,var/lib}
mount /dev/nvme0n1p1 /mnt/efi
mount /dev/nvme0n1p2 /mnt/boot
mount /dev/vg0/home /mnt/home
mount /dev/vg0/lib  /mnt/var/lib

pacstrap -K /mnt base linux linux-firmware lvm2 btrfs-progs grub efibootmgr \
    intel-ucode networkmanager nvidia-open zram-generator sof-firmware \
    terminus-font sudo vim git openssh
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

## mkinitcpio (`/etc/mkinitcpio.conf`)

```
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt lvm2 filesystems fsck)
```

This is the systemd flavor (what the Legion runs): take the stock default line and insert
`sd-encrypt lvm2` before `filesystems`. The load-bearing parts: `sd-encrypt` **before**
`lvm2`, both before `filesystems`; `sd-vconsole` reads /etc/vconsole.conf so the
passphrase prompt gets the Swedish keymap. The nvidia MODULES require the nvidia driver
installed. Then `mkinitcpio -P`.
("possibly missing firmware for module qat_6xxx" is a benign warning — Intel QuickAssist,
unused. The X1E ran the legacy variant instead: `udev`+`encrypt`+`keymap consolefont`
hooks with `cryptdevice=` on the kernel cmdline — the two dialects must not be mixed.)

## GRUB (`/etc/default/grub`)

```
GRUB_CMDLINE_LINUX="rd.luks.name=<luks-uuid>=cryptlvm rd.luks.options=discard root=/dev/vg0/root"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1"
```

`rd.luks.*` is the sd-encrypt syntax (the Legion setup). Fill the UUID with
`blkid -s UUID -o value /dev/nvme0n1p3`. `rd.luks.options=discard` lets TRIM pass
through dm-crypt — audit of the old machine found TRIM never reached its SSD.
Also `systemctl enable fstrim.timer` after install.
(The X1E's legacy equivalent was `cryptdevice=UUID=...:cryptlvm:allow-discards` plus
`GRUB_ENABLE_CRYPTODISK=y`; use that only with the legacy `encrypt` hook.)

## Swap: zram (new on the Legion — the X1E ran without swap)

```
printf '[zram0]\nzram-size = ram / 2\ncompression-algorithm = zstd\n' > /etc/systemd/zram-generator.conf
```
(`zram-generator` is in the pacstrap list; the device appears on next boot.)

```
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

Note: the old machine ran with Secure Boot **disabled**. Keep it disabled (or set up
sbctl separately) — GRUB + out-of-tree nvidia won't boot with it on otherwise.

## After first boot

```
git clone <dotfiles repo> ~/dotfiles && cd ~/dotfiles
sudo pacman -S --needed - < packages/pacman.txt
paru -S --needed - < packages/aur.txt      # bootstrap paru manually first
./install.sh                                # symlinks + prints the system/ manual steps
```

## Legion Pro 5 16IAX10H specifics (target machine, 2026-09)

Core Ultra 9 275HX (Arrow Lake-HX) + RTX 5070 Ti (Blackwell) + 16" 2560x1600 OLED 165/240 Hz.

- **Use `nvidia-open`, not `nvidia`** — the proprietary kernel modules do not support
  Blackwell. MODULES/cmdline names (`nvidia_drm` etc.) stay the same.
- `intel-ucode` as written above.
- Needs a recent ISO — the 2024.03 stick's kernel predates both Arrow Lake and Blackwell.
- Fan/power profiles: `legion-laptop` module from AUR (thinkpad_acpi does nothing here).
- Hyprland monitor line: `eDP-1,2560x1600@165` (or @240 — check `hyprctl monitors`),
  pick scale by taste (1.25 or 1.6).

Machine-specific things that need review on new hardware (do NOT copy blindly):
monitor line + `AQ_DRM_DEVICES` in `hypr/`, `system/modprobe-nvidia.conf`,
and the udev rules that create `/dev/dri/intel-igpu` / `nvidia-dgpu` symlinks
(live in `/etc/udev/rules.d/`, not yet in this repo).
