{ cosmic-comp, noctalia, cosmic-settings, cosmic-settings-daemon, xdg-desktop-portal-wlr, xdg-desktop-portal-gnome, polkit, gnome-keyring, wireplumber, cosmic-screenshot, stdenv, makeWrapper, lib, src }:

let
  version = "1.2.3";
in
stdenv.mkDerivation rec {
  pname = "cosmalia-session";
  inherit version;
  inherit src;

  # No build phase needed - we just install files
  nativeBuildInputs = [ makeWrapper ];

  # Runtime dependencies
  propagatedBuildInputs = [
    cosmic-comp
    noctalia
    cosmic-settings
    cosmic-settings-daemon
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gnome
    polkit
    gnome-keyring
    wireplumber
    cosmic-screenshot
  ];

  # The package is architecture independent
  meta = {
    description = "Cosmalia: minimal COSMIC desktop with cosmic-comp and Noctalia";
    longDescription = ''
      Cosmalia is a lightweight, modern Linux desktop that runs in under 1 GB of RAM.
      It combines two projects:

      - cosmic-comp: the COSMIC compositor with macOS-style traffic-light
        window buttons, Wayland blur, animations, 3-finger workspace swipes, and built-in Alt+Tab
      - Noctalia: the shell (bar, dock, launcher, notifications, networking, lock screen,
        idle/suspend, MPRIS, screensaver, and a polkit agent)

      This package provides the XDG session entry, systemd user units, portal configuration,
      and an optional greeter helper.
    '';
    homepage = "https://github.com/grigio/cosmalia-session";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.all;
  };

  # Install phase: copy the files tree to $out
  installPhase = ''
    mkdir -p $out
    
    # Copy files with write permissions so we can create subdirectories
    cp -r $src/files/* $out/
    # Make sure all directories are writable
    find $out -type d -exec chmod u+w {} \;

    # Install the helper script and docs
    mkdir -p $out/usr/bin
    mkdir -p $out/usr/share/doc/cosmalia-session
    mkdir -p $out/usr/share/licenses/cosmalia-session

    cp $src/scripts/set-default-greetd.sh $out/usr/bin/cosmalia-session-default
    chmod +x $out/usr/bin/cosmalia-session-default

    cp $src/README.md $out/usr/share/doc/cosmalia-session/README.md
    cp $src/LICENSE $out/usr/share/licenses/cosmalia-session/LICENSE

    # Ensure the session launcher is executable
    chmod +x $out/usr/bin/cosmalia-session
  '';

  # Ensure systemd user units are in the right place
  postInstall = ''
    # The files already have the correct structure under usr/
    # Verify the structure
    test -f $out/usr/bin/cosmalia-session
    test -f $out/usr/share/wayland-sessions/cosmalia.desktop
    test -f $out/usr/share/xdg-desktop-portal/cosmalia-portals.conf
    test -f $out/usr/lib/systemd/user/cosmalia-session.target
    test -f $out/usr/lib/systemd/user/noctalia.service
    test -f $out/usr/lib/systemd/user/cosmic-settings-daemon.service
    test -f $out/usr/bin/cosmalia-session-default
  '';

  # No tests needed
  doCheck = false;

  # No strip needed for scripts and config files
  dontStrip = true;
}