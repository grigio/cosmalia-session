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

# greetd is a daemon: PAM_TTY is not set, so pam_securetty refuses the login
# and the autologin session never starts (falls back to the greeter).
sed -i '/pam_securetty\.so/d' /etc/pam.d/greetd

# Services that pull in nothing the live session uses.
rm -f /etc/systemd/system/multi-user.target.wants/remote-fs.target
rm -f /etc/systemd/system/sockets.target.wants/systemd-userdbd.socket
ln -sfn /dev/null /etc/systemd/system/systemd-userdbd.socket
ln -sfn /dev/null /etc/systemd/system/systemd-userdbd.service
rm -f /etc/systemd/user/sockets.target.wants/p11-kit-server.socket
