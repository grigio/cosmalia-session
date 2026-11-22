# Cosmalia live ISO (CachyOS base)

A minimal, CachyOS-based live ISO that boots straight into the Cosmalia
desktop (`cosmic-comp-traffic` compositor + Noctalia shell).

## What is in it

- Mainline CachyOS kernel (`linux-cachyos`) with an archiso initramfs and CPU microcode
- CachyOS/Arch repos configured in the live system
- `cosmalia-session` and `cosmic-comp-traffic` built from the local source
  trees (`../` and `~/Code/cosmic-comp-traffic`)
- Noctalia, portals, pipewire/wireplumber, polkit, NetworkManager, foot
- greetd + gtkgreet (in `cage`) as the login manager: `initial_session`
  autologins `liveuser` into Cosmalia, logging out returns to the GTK greeter
  with Cosmalia preselected (`/etc/greetd/config.toml`)
- No KDE/GNOME/calamares; Noctalia settings are sanitised (no user paths or
  plugins) and the current user's cosmic-comp shortcuts are shipped in skel
- Trimmed: no `foot` (Alacritty is the terminal), no qemu-guest-agent, no
  remote-fs or p11-kit socket; the buggy cosmic portal backend and the
  keyring prompter are disabled via D-Bus stubs

## Build

```sh
# host needs: archiso mkinitcpio-archiso squashfs-tools grub
./build.sh
```

Outputs:

- `out/cosmalia-cachyos-<version>-x86_64.iso`
- `local-repo/` (local pacman repository with the two custom packages)

Nothing is installed on the host; only `mkarchiso` runs via `sudo`.

## Test in QEMU

```sh
./test.sh
```

Boots the ISO with KVM, OVMF (UEFI), QXL graphics and a serial console. The
script uses QEMU's guest agent to verify packages/services inside the VM,
captures screenshots of the desktop and the greetd greeter, and saves all
evidence under `test-results/`.
