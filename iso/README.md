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
- **CachyOS installer**: Calamares (`cachyos-calamares-next`) in offline mode
  installs this exact live environment to disk. Launch **Install Cosmalia**
  from the app menu, or run `cosmalia-installer`. Bootloader is **Limine**
  (UEFI and BIOS), with a normal non-archiso initramfs generated on install
- No KDE/GNOME; Noctalia settings are sanitised (no user paths or plugins) and
  the current user's cosmic-comp shortcuts are shipped in skel
- Trimmed: no `foot` (Alacritty is the terminal), no qemu-guest-agent, no
  remote-fs or p11-kit socket; the buggy cosmic portal backend and the
  keyring prompter are disabled via D-Bus stubs

## Build

```sh
# host needs: archiso mkinitcpio-archiso squashfs-tools grub curl
./build.sh
```

`build.sh` also fetches Boost 1.91 libraries from the Arch package archive:
the packaged `cachyos-calamares-next` is still built against that ABI while
CachyOS currently ships Boost 1.92. They are added side by side in the image.
Set `ISO_BOOST_URL` / `ISO_BOOST_CACHE` to override the source.

Outputs:

- `out/cosmalia-cachyos-<version>-x86_64.iso`
- `local-repo/` (local pacman repository with the two custom packages)

Nothing is installed on the host; only `mkarchiso` runs via `sudo`.

## Test in QEMU

```sh
./test.sh              # verify the live desktop and greeter
./test-installer.sh    # boot with a blank disk and exercise the installer
```

Both boot the ISO with KVM, OVMF (UEFI), QXL graphics and a serial console.
`test.sh` uses QEMU's guest agent to verify packages/services inside the VM and
captures screenshots of the desktop and the greetd greeter.

`test-installer.sh` attaches an empty 40 GiB virtio disk, checks that
Calamares/Limine and the custom configuration are present, then starts
Calamares in the live Wayland session and captures a screenshot. Evidence is
written under `test-results/installer/`.

For a full interactive installation, leave the VM running with
`./run-installer-vm.sh` and drive the wizard with
`python3 installer-drive.py test-results/installer`. Afterwards boot the
installed disk with `./test-installed.sh`. Helper tools: `qga.py` (run
commands in the guest via QEMU Guest Agent), `vmctl.py` (keyboard, mouse,
screenshots), e.g.:

```sh
python3 vmctl.py test-results/installer screenshot welcome
python3 vmctl.py test-results/installer click 500 400
python3 vmctl.py test-results/installer shell 'lsblk /dev/vda'
```

`./run-installed-vm.sh` boots the installed disk in a persistent GTK window
(using the native Wayland backend, no XWayland). It reuses
`test-results/installer/disk.qcow2` and the OVMF variables containing Limine's
EFI entry; the monitor/QMP/serial/guest-agent sockets stay available for the
helpers above.
