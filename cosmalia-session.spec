# Cosmalia session RPM spec file
# Fedora package for Cosmalia: a minimal COSMIC-based Wayland desktop
# built on cosmic-comp-traffic and Noctalia.
#
# Build: rpmbuild -ba cosmalia-session.spec
# Requires: rpmbuild, rpmdevtools, fedora-review

%global _hardened_build 1

Name:           cosmalia-session
Version:        %{version}
Release:        %{release}%{?dist}
Summary:        Minimal COSMIC desktop with cosmic-comp-traffic and Noctalia

License:        MIT
URL:            https://github.com/grigio/cosmalia-session
Source0:        cosmalia-session-%{version}.tar.gz

BuildArch:      noarch
BuildRequires:  systemd-rpm-macros
Requires:       cosmic-comp
Requires:       noctalia
Requires:       cosmic-settings
Requires:       cosmic-settings-daemon
Requires:       xdg-desktop-portal-wlr
Requires:       xdg-desktop-portal-gnome
Requires:       polkit
Requires:       gnome-keyring
Requires:       wireplumber
Requires:       cosmic-screenshot

# Optional but recommended
Recommends:     polkit-gnome
Recommends:     zram-generator
Recommends:     systemd-oomd

# Obsoletes the old package name
Obsoletes:      cosmic-comp-traffic-session < %{version}
Provides:       cosmic-comp-traffic-session = %{version}
Conflicts:      cosmic-comp-traffic-session

%description
Cosmalia is a minimal COSMIC-based Wayland desktop environment designed to run
in under 1 GB of RAM. It uses cosmic-comp-traffic (a patched COSMIC compositor
with macOS-style traffic-light decorations, wlr-foreign-toplevel support,
3-finger workspace swipe, and in-process Alt+Tab) together with Noctalia
(shell, bar, dock, launcher, notifications, lock screen, idle/suspend handling,
polkit agent, MPRIS, and screensaver).

This package installs:
- The session launcher (/usr/bin/cosmalia-session)
- The XDG session entry (/usr/share/wayland-sessions/cosmalia.desktop)
- Systemd user units for the session target, Noctalia, and cosmic-settings-daemon
- Portal configuration for xdg-desktop-portal
- A helper script to make Cosmalia the default in gtkgreet (/usr/bin/cosmalia-session-default)

The package does NOT edit /etc/greetd and does NOT make Cosmalia the default
session; run `sudo cosmalia-session-default` explicitly to do that.

%prep
%autosetup -n cosmalia-session-%{version} -p1

%build
# No build step needed - all files are pre-built in the source tree
# The source is the repo itself, layout mirrors /

%install
rm -rf %{buildroot}

# Install the file tree from files/ (mirrors /)
cp -a files/. %{buildroot}/

# Install the helper script
install -Dm755 scripts/set-default-greetd.sh %{buildroot}/%{_bindir}/cosmalia-session-default

# Install documentation
install -Dm644 README.md %{buildroot}/%{_docdir}/%{name}/README.md
install -Dm644 LICENSE %{buildroot}/%{_licensedir}/%{name}/LICENSE

%files
%{_bindir}/cosmalia-session
%{_bindir}/cosmalia-session-default
%{_datadir}/wayland-sessions/cosmalia.desktop
%{_datadir}/xdg-desktop-portal/cosmalia-portals.conf
%{_prefix}/lib/systemd/user/cosmalia-session.target
%{_prefix}/lib/systemd/user/noctalia.service
%{_prefix}/lib/systemd/user/cosmic-settings-daemon.service
%{_docdir}/%{name}/README.md
%license %{_licensedir}/%{name}/LICENSE

%changelog
* %{changelog_date} %{changelog_name} <%{changelog_email}> - %{version}-%{release}
- Initial RPM package for Fedora