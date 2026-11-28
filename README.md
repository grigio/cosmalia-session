# Cosmalia. Modern Minimal Linux Desktop under 400Mb Ram

![Cosmalia](docs/cosmalia.gif)

**Cosmalia** is built from these components:

- [cosmic-comp-traffic](https://github.com/grigio/cosmic-comp-traffic) - COSMIC Wayland compositor (traffic-light decorations, blur, animations, 3-finger swipes, in-process Alt+Tab)
- [noctalia](https://github.com/noctalia-dev/noctalia) - Shell: bar, dock, launcher, notifications, lock screen, idle/suspend, MPRIS, polkit agent
- archlinux/cachyos - it could work also on other Linux distros but aren't tested. An equivalent session for artix dinit is avalable at [cosmalia-session-dinit](https://github.com/grigio/cosmalia-session-dinit)

`cosmalia-session` is the opinionated XDG session that starts them together. It appears in any Wayland-capable login manager (like greetd). You can install Cosmalia in archlinux/cachyos or try/install Cosmalia via Live ISO attached in the [releases](https://github.com/grigio/cosmalia-session/releases).

## Try it first: Live ISO

The **CachyOS-based live ISO** boots straight into the Cosmalia desktop. Run it
from a USB stick or in a VM to try the whole session before installing — nothing
is written to disk (the live root filesystem lives in RAM).

```sh
gh release download --latest -R grigio/cosmalia-session -p '*.iso' -D /tmp/cosmalia-iso
# then flash /tmp/cosmalia-iso/*.iso to a USB stick, or boot the ISO in a VM
```

The boot menu offers three entries: **Cosmalia Live (CachyOS)** (autologin as
`liveuser`), **Cosmalia Live (Intel Panther Lake)** with Intel GPU/Wi-Fi
workarounds, and **Cosmalia Live (nomodeset fallback)** if the desktop fails to
start. Logging out returns to the greetd greeter with Cosmalia preselected.

The ISO ships the **CachyOS installer** (Calamares) in offline mode: it installs
this exact live environment to disk, with no downloads or extra packages. Pick
**Install Cosmalia** in the app menu (or run `cosmalia-installer`); the installed
system boots with **Limine** on both UEFI and BIOS. See
[iso/README.md](iso/README.md) for the full package list and QEMU test commands.

<details>
<summary>Build the ISO yourself</summary>

The host needs `archiso`, `mkinitcpio-archiso`, `squashfs-tools`, `grub` and
`curl` (the build also fetches Boost 1.91 into `local-repo/` for Calamares):

```sh
cd iso && ./build.sh      # -> iso/out/cosmalia-cachyos-*-x86_64.iso
```

Nothing is installed on the host; only `mkarchiso` runs via `sudo`. Use
`ISO_BOOST_URL` / `ISO_BOOST_CACHE` to override the Boost source.

</details>

## Install

If you installed from the live ISO with **Install Cosmalia**, skip this section —
the session is already on disk. The commands below use the
[GitHub CLI](https://cli.github.com/) (`gh`); the same assets are attached to the
[releases page](https://github.com/grigio/cosmalia-session/releases).

### Arch Linux / CachyOS (recommended)

```sh
gh release download --latest -R grigio/cosmalia-session -p '*.pkg.tar.zst' -D /tmp/cosmalia
sudo pacman -U /tmp/cosmalia/*.pkg.tar.zst
# or build from this checkout: makepkg -fi
```

The package is architecture-independent, pulls in its dependencies automatically
(see [What you get](#what-you-get)), and never changes your greeter configuration.

<details>
<summary>From a git checkout, without a package</summary>

For development, run `./scripts/install.sh` as your normal user. It uses `sudo`
only for `/usr`, installs the same files as the package, reloads your user
systemd manager, and refuses to overwrite files owned by pacman. It checks that
`/usr/bin/cosmic-comp`, Noctalia and both portal backends are present first.
Add `--default` to also make Cosmalia the greeter default. Prefer the package on
any system where pacman owns these paths.

</details>

<details>
<summary>Other distros: Fedora and NixOS (untested)</summary>

**Fedora**

```sh
gh release download --latest -R grigio/cosmalia-session -p '*.rpm' -D /tmp/cosmalia-session
sudo dnf install /tmp/cosmalia-session/*.rpm
# or build locally from this checkout:
#   rpmbuild -ba cosmalia-session.spec
#   sudo dnf install ~/rpmbuild/RPMS/noarch/cosmalia-session-*.noarch.rpm
```

**NixOS** — add the flake input and module to your `flake.nix`:

```nix
{
  inputs = { cosmalia-session.url = "github:grigio/cosmalia-session"; };
  outputs = { self, nixpkgs, cosmalia-session, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        cosmalia-session.nixosModules.cosmalia-session
        {
          services.cosmalia-session = {
            enable = true;
            # defaultSession = true;   # greetd: launch Cosmalia directly
            # enableXWayland = true;   # default is false
          };
        }
      ];
    };
  };
}
```

Module options: `enable`, `package`, `defaultSession`, `enableXWayland` and
`extraPackages`. `nix develop github:grigio/cosmalia-session` gives you a shell
with the project's formatter and linter.

</details>

## First login

The package ships `/usr/share/wayland-sessions/cosmalia.desktop`, so display
managers that scan it (GDM, SDDM, Noctalia Greeter, …) list **Cosmalia** — but
none of them switch to it by default, and the package never edits your greeter
config. **gtkgreet** is the exception: it only reads `/etc/greetd/environments`
and its `-c` argument, so use the helper below.

With **greetd + gtkgreet**:

```sh
sudo cosmalia-session-default            # default + add to the dropdown
sudo cosmalia-session-default --list     # only add to the dropdown
```

greetd reads its configuration only at startup, so the change takes effect after
a reboot, or after `sudo systemctl restart greetd` **while logged out**. Both
commands keep timestamped backups of the files they touch (last three kept).

With **Noctalia Greeter**, select "Cosmalia" once in the greeter, or put
`default = "Cosmalia"` in `/var/lib/noctalia-greeter/greeter.toml`. For other
greeters, choose Cosmalia in their session menu.

## What you get

The session starts exactly three things: `cosmic-comp` (the compositor, with
`--no-xwayland` by default), `noctalia.service` (bar, dock, launcher,
notifications, lock screen, idle/suspend, MPRIS, polkit agent) and
`cosmic-settings-daemon.service` (live theme and keybinding reloads). The two
services are supervised by systemd, so they restart on crash and log to the
journal; portals, PipeWire/WirePlumber, gnome-keyring and D-Bus come up on
demand.

Installed automatically: `cosmic-comp-traffic` (provides `/usr/bin/cosmic-comp`),
`noctalia`, `cosmic-settings-daemon`, `xdg-desktop-portal-wlr` (screenshots and
screencasts), `xdg-desktop-portal-gtk` (file dialogs), `polkit`, `gnome-keyring`
and `wireplumber`. Optional extras: `cosmic-settings`, `cosmic-screenshot`,
`inotify-tools`, `polkit-gnome`, `zram-generator` and `systemd-oomd`.

<details>
<summary>Why no xdg-desktop-portal-cosmic?</summary>

The COSMIC portal backend is currently buggy (it crashes on
`ext_image_copy_capture_session_v1`), so it is deliberately excluded. The shipped
`cosmalia-portals.conf` sends FileChooser to the GTK backend, Screenshot and
ScreenCast to the wlr backend, and Secret to gnome-keyring; Settings,
RemoteDesktop and Access stay unavailable. Noctalia handles notifications, idle
and suspend itself, and its built-in agent handles polkit requests.

</details>

<details>
<summary>Configuration: XWayland and zram</summary>

**XWayland** is off by default. To enable it, create
`~/.config/cosmalia/session.conf`:

```sh
mkdir -p ~/.config/cosmalia
echo 'COSMALIA_NO_XWAYLAND=0' > ~/.config/cosmalia/session.conf
```

Log out and back in. A value exported by your greeter (or NixOS'
`services.cosmalia-session.enableXWayland`) overrides the file — no
`systemctl --user` reload is needed, the launcher reads it before starting the
compositor. Delete the line or the file to revert.

**zram** (optional, helps stay under 400 MB of RAM): install `zram-generator`,
then:

```sh
echo -e '[zram0]\nzram-size = min(ram, 4096)\ncompression-algorithm = zstd\nswap-priority = 100' \
  | sudo tee /etc/systemd/zram-generator.conf
sudo systemctl enable --now systemd-zram-setup@zram0.service
```

</details>

<details>
<summary>Troubleshooting</summary>

The launcher writes to `$XDG_RUNTIME_DIR/cosmalia-session.log` (truncated at each
login); Noctalia and cosmic-settings-daemon log to the user journal:

```sh
tail -f "$XDG_RUNTIME_DIR/cosmalia-session.log"
journalctl --user -b -u noctalia.service -u cosmic-settings-daemon.service
```

| Symptom | Check |
|---------|-------|
| Session exits immediately | `XDG_RUNTIME_DIR` must exist — log in through a greeter/logind, not a bare console |
| Noctalia won't start | `journalctl --user -b -u noctalia.service` |
| Screenshots fail | `systemctl --user status xdg-desktop-portal.service org.freedesktop.impl.portal.desktop.wlr.service` |
| File dialogs broken | `pacman -Q xdg-desktop-portal-gtk` and check `cosmalia-portals.conf` |
| Traffic lights missing | `pacman -Q cosmic-comp-traffic` — it must provide `/usr/bin/cosmic-comp` |
| Greeter doesn't default | `sudo cosmalia-session-default`, then restart greetd |

</details>

<details>
<summary>Uninstall</summary>

```sh
sudo pacman -R cosmalia-session     # Arch / CachyOS
sudo dnf remove cosmalia-session    # Fedora
# NixOS: remove the module from your flake and rebuild
```

Removing the package does not touch your greeter config. If Cosmalia is the
greeter default, pick another session first — the `pre_remove` hook only warns —
or restore one of the timestamped backups left by `cosmalia-session-default`
beside the config:

```sh
sudo cp -a /etc/greetd/config.toml.bak.<timestamp> /etc/greetd/config.toml
```

Installing `cosmalia-session` replaces the older `cosmic-comp-traffic-session`
package automatically.

</details>

## FAQ

- **Hybrid tiling?** Yes — `SUPER + Y`.
- **Use upstream `cosmic-comp` instead?** It works but lacks the fork's extras
  (traffic-light decorations, blur, animations, 3-finger swipes, in-process
  Alt+Tab). The binary is called `cosmic-comp` either way; the choice is which
  package provides it.
- **Cosmic Settings or Noctalia settings?** Both — complementary. Window and
  compositor behaviour and keyboard shortcuts live in Cosmic Settings; bar,
  dock, launcher, notifications, lock and idle live in Noctalia settings.
- **X11 apps?** XWayland is off by default to save memory; enable it as shown in
  Configuration above.
- **Other hardware or no systemd?** The CachyOS package targets x86-64-v3 and
  the session relies on systemd. On older CPUs, or if you don't want systemd,
  use [cosmalia-session-dinit](https://github.com/grigio/cosmalia-session-dinit)
  (Artix Linux + dinit). The NixOS flake also builds for `aarch64-linux`.
- **Other distros?** Fedora RPMs and a NixOS module are published but untested;
  other systemd distros may work if the dependencies are available. The live ISO
  is the surest way to try it.

## License

MIT, see [LICENSE](LICENSE).
