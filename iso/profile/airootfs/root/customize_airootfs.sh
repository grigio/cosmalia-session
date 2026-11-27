#!/usr/bin/env bash
# Runs inside the ISO chroot after all packages are installed.
set -euo pipefail

# A live session must not show the "Choose password for new keyring" dialog.
# Keep the gnome-keyring package (a cosmalia-session dependency) but make the
# D-Bus Secret Service activation a no-op so no prompter is launched.
cat >/usr/share/dbus-1/services/org.freedesktop.secrets.service <<'EOF'
[D-BUS Service]
Name=org.freedesktop.secrets
Exec=/usr/bin/true
EOF
chmod 0644 /usr/share/dbus-1/services/org.freedesktop.secrets.service

# cosmalia-portals.conf routes Screenshot/ScreenCast to the wlr backend and
# FileChooser to GTK; the cosmic backend is explicitly unused (and buggy).
# Make sure it can never be started by D-Bus activation.
cat >/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.cosmic.service <<'EOF'
[D-BUS Service]
Name=org.freedesktop.impl.portal.desktop.cosmic
Exec=/usr/bin/true
EOF
chmod 0644 /usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.cosmic.service

# Initialise the pacman keyring so `pacman -Syu` works in the live system.
pacman-key --init
pacman-key --populate archlinux cachyos

# greetd is a daemon: PAM_TTY is not set, so pam_securetty refuses the login
# and the autologin session never starts (falls back to the greeter).
sed -i '/pam_securetty\.so/d' /etc/pam.d/greetd

# Services that pull in nothing the live session uses.
rm -f /etc/systemd/system/multi-user.target.wants/remote-fs.target
rm -f /etc/systemd/system/sockets.target.wants/systemd-userdbd.socket
ln -sfn /dev/null /etc/systemd/system/systemd-userdbd.socket
ln -sfn /dev/null /etc/systemd/system/systemd-userdbd.service
rm -f /etc/systemd/user/sockets.target.wants/p11-kit-server.socket

# Calamares needs Boost.Python 1.91 (built against that ABI); keep the 1.91
# libraries shipped in the overlay alongside the distro's 1.92 ones.
chmod 0755 /usr/lib/libboost_*.so.1.91.0 2>/dev/null || true
ldconfig

# Override the Calamares module configs shipped by cachyos-calamares-next.
# They cannot live in the airootfs overlay directly: pacstrap rejects a package
# that tries to install over an existing file.
if [[ -d /root/calamares-overlay/modules ]]; then
  cp -f /root/calamares-overlay/modules/*.conf /etc/calamares/modules/
  rm -rf /root/calamares-overlay
fi

# The Cosmalia Calamares branding only ships branding.desc; reuse the CachyOS
# images/QML assets so the installer looks native to the distribution.
brand_dir=/usr/share/calamares/branding
if [[ -d "$brand_dir/cachyos" && -d "$brand_dir/cosmalia" ]]; then
  cp -f "$brand_dir"/cachyos/{icon.png,logo.png,welcome.png,show.qml,stylesheet.qss,calamares-sidebar.qml} \
        "$brand_dir/cosmalia/" 2>/dev/null || true
  cp -f "$brand_dir"/cachyos/slide*.jxl "$brand_dir/cosmalia/" 2>/dev/null || true
fi

