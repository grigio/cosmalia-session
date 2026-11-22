# Cosmalia

A minimal COSMIC-based Wayland desktop in under 400 MB. It combines
**cosmic-comp-traffic** (patched compositor with macOS-style traffic lights,
Wayland blur, three-finger workspace swipes and in-process Alt+Tab) and
**Noctalia** (bar, dock, launcher, notifications, lock screen, idle/suspend,
MPRIS, polkit agent).

![Cosmalia](docs/cosmalia.gif)

## Try it first: Live ISO

A **CachyOS-based live ISO** boots straight into the Cosmalia desktop. Use it on
a USB stick or in a VM to try everything before installing. Nothing is written
to disk.

Download the latest ISO from the [releases page](https://github.com/grigio/cosmalia-session/releases):

```sh
gh release download --latest -R grigio/cosmalia-session -p '*.iso' -D /tmp/cosmalia-iso
```

Or build it yourself (needs `archiso`, `grub`, `squashfs-tools`):

```sh
cd iso && ./build.sh      # -> iso/out/cosmalia-cachyos-*-x86_64.iso
```

The boot menu offers a default entry (autologin into Cosmalia), an Intel
Panther Lake quirks entry, and a nomodeset fallback. See [iso/README.md](iso/README.md)
for details and QEMU testing.

## Not a fit? Use cosmalia-session-dinit

Cosmalia targets x86-64-v3 and relies on systemd. If your computer is older and
does not support x86-64-v3, or if you simply do not want systemd, consider
[cosmalia-session-dinit](https://github.com/grigio/cosmalia-session-dinit)
instead. It is the same desktop built on
[Artix Linux](https://artixlinux.org/) with dinit as the init system.

## Install

### Arch Linux (recommended)

```sh
# From the latest release
gh release download --latest -R grigio/cosmalia-session -p '*.pkg.tar.zst' -D /tmp/cosmalia
sudo pacman -U /tmp/cosmalia/*.pkg.tar.zst

# Or build locally
makepkg -fi
```

### Fedora

```sh
# From the latest release
gh release download --latest -R grigio/cosmalia-session -p '*.rpm' -D /tmp/cosmalia-session
sudo dnf install /tmp/cosmalia-session/*.rpm

# Or build locally
rpmbuild -ba cosmalia-session.spec
sudo dnf install ~/rpmbuild/RPMS/noarch/cosmalia-session-*.noarch.rpm
```

### NixOS

```nix
# flake.nix
{
  inputs = { cosmalia-session.url = "github:grigio/cosmalia-session"; };
  outputs = { self, nixpkgs, cosmalia-session, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        cosmalia-session.nixosModules.cosmalia-session
        ({ ... }: { services.cosmalia-session.enable = true; })
      ];
    };
  };
}
```

## First login

Cosmalia appears in your greeter (greetd, GDM, SDDM, …) as **Cosmalia**, but is
not the default. For gtkgreet:

```sh
sudo cosmalia-session-default            # make it the default
sudo cosmalia-session-default --list     # just add it to the dropdown
```

## What you get

Dependencies install automatically: `cosmic-comp-traffic`, `noctalia`,
`cosmic-settings-daemon`, `xdg-desktop-portal-wlr` (screenshots/screencast),
`xdg-desktop-portal-gtk` (file dialogs), `polkit`, `gnome-keyring` and
`wireplumber`. Optional extras: `cosmic-settings`, `cosmic-screenshot`,
`inotify-tools`, `polkit-gnome`, `zram-generator`.

`xdg-desktop-portal-cosmic` is intentionally avoided because it is currently buggy.
Interfaces that require it (Settings, RemoteDesktop, Access) are unavailable by
design; notifications are handled directly by Noctalia.

## Configuration

**XWayland** is off by default. To enable it, create `~/.config/cosmalia/session.conf`:

```sh
mkdir -p ~/.config/cosmalia
echo 'COSMALIA_NO_XWAYLAND=0' > ~/.config/cosmalia/session.conf
```

Log out and back in. A value exported by your greeter (or NixOS'
`services.cosmalia-session.enableXWayland`) takes precedence; no
`systemctl --user` reload is needed.

**zram** (optional, helps stay under 400 MB): install `zram-generator`, then:

```sh
echo -e '[zram0]\nzram-size = min(ram, 4096)\ncompression-algorithm = zstd\nswap-priority = 100' \
  | sudo tee /etc/systemd/zram-generator.conf
sudo systemctl enable --now systemd-zram-setup@zram0.service
```

## Troubleshooting

```sh
tail -f "$XDG_RUNTIME_DIR/cosmalia-session.log"                          # compositor/launcher
journalctl --user -b -u noctalia.service -u cosmic-settings-daemon.service  # shell
```

| Issue | Check |
|-------|-------|
| Noctalia won't start | `journalctl --user -b -u noctalia.service` |
| Screenshots fail | `systemctl --user status xdg-desktop-portal.service org.freedesktop.impl.portal.desktop.wlr.service` |
| File dialogs broken | `pacman -Q xdg-desktop-portal-gtk` and check `cosmalia-portals.conf` |
| Traffic lights missing | `pacman -Q cosmic-comp-traffic` must provide `/usr/bin/cosmic-comp` |
| Greeter doesn't default | `sudo cosmalia-session-default` |

## Uninstall

```sh
sudo pacman -R cosmalia-session     # Arch
sudo dnf remove cosmalia-session    # Fedora
# NixOS: remove the module from your flake
```

On Arch/Fedora the `pre_remove` hook warns if Cosmalia is the greeter default.
Restore your previous config first. Installing `cosmalia-session` replaces the
older `cosmic-comp-traffic-session` package automatically.

## License

MIT, see [LICENSE](LICENSE).
