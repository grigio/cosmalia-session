{
  lib,
  stdenv,
  version ? lib.strings.trim (builtins.readFile ../VERSION),
  src,
  cosmic-comp,
  noctalia,
  cosmic-settings-daemon,
  dbus,
  xdg-desktop-portal-wlr,
  xdg-desktop-portal-gtk,
  polkit,
  gnome-keyring,
  wireplumber,
  systemd,
  coreutils,
  gawk,
  gnugrep,
  findutils,
  binutils,
  iproute2,
  inotify-tools,
}: let
  # The launcher and the user units are written for an FHS system where every
  # helper lives in /usr/bin. That directory does not exist on NixOS, so the
  # Nix build rewrites the absolute paths to store paths. The files shipped
  # for Arch/Fedora stay untouched.
  runtimeBins = {
    "cosmic-comp" = "${cosmic-comp}/bin/cosmic-comp";
    "noctalia" = "${noctalia}/bin/noctalia";
    "cosmic-settings-daemon" = "${cosmic-settings-daemon}/bin/cosmic-settings-daemon";
    "systemctl" = "${systemd}/bin/systemctl";
    "dbus-update-activation-environment" = "${dbus}/bin/dbus-update-activation-environment";
    "timeout" = "${coreutils}/bin/timeout";
    "ss" = "${iproute2}/bin/ss";
    "awk" = "${gawk}/bin/awk";
    "grep" = "${gnugrep}/bin/grep";
    "find" = "${findutils}/bin/find";
    "strings" = "${binutils}/bin/strings";
    "inotifywait" = "${inotify-tools}/bin/inotifywait";
  };

  substituteFlagsFor = names:
    lib.concatStringsSep " " (
      lib.mapAttrsToList (name: path: "--replace '/usr/bin/${name}' '${path}'") (
        lib.filterAttrs (name: _: lib.elem name names) runtimeBins
      )
    );

  # NixOS names the wlr portal unit differently from FHS distros.
  nixFlags = "--replace 'org.freedesktop.impl.portal.desktop.wlr.service' 'xdg-desktop-portal-wlr.service'";

  allFlags = substituteFlagsFor (lib.attrNames runtimeBins) + " " + nixFlags;
  unitFlags = substituteFlagsFor ["cosmic-comp" "noctalia" "cosmic-settings-daemon"];
in
  stdenv.mkDerivation rec {
    pname = "cosmalia-session";
    inherit version src;

    # No build tools are needed: the files are copied and paths are rewritten
    # in installPhase. cosmic-settings and cosmic-screenshot are ordinary apps,
    # not session dependencies, so they are deliberately not propagated here.

    propagatedBuildInputs = [
      cosmic-comp
      noctalia
      cosmic-settings-daemon
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
      polkit
      gnome-keyring
      wireplumber
      # Binaries referenced by the launcher through absolute paths.
      dbus
      systemd
      coreutils
      gawk
      gnugrep
      findutils
      binutils
      iproute2
      inotify-tools
    ];

    meta = {
      description = "Cosmalia: minimal COSMIC desktop with cosmic-comp-traffic and Noctalia";
      longDescription = ''
        Cosmalia is a lightweight, modern Linux desktop that runs in less than 400 MB of RAM.
        It combines two projects:

        - cosmic-comp-traffic: the COSMIC compositor fork with macOS-style traffic-light
          window buttons, Wayland blur, animations, 3-finger workspace swipes, and built-in Alt+Tab
        - Noctalia: the shell (bar, dock, launcher, notifications, networking, lock screen,
          idle/suspend, MPRIS, screensaver, and a polkit agent)

        This package provides the XDG session entry, systemd user units, portal configuration,
        and an optional greeter helper.
      '';
      homepage = "https://github.com/grigio/cosmalia-session";
      license = lib.licenses.mit;
      mainProgram = "cosmalia-session";
      platforms = lib.platforms.linux;
    };

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r $src/files/* $out/
      find $out -type d -exec chmod u+w {} \;

      # Helper script and documentation
      mkdir -p $out/usr/bin
      mkdir -p $out/usr/share/doc/cosmalia-session
      mkdir -p $out/usr/share/licenses/cosmalia-session
      cp $src/scripts/set-default-greetd.sh $out/usr/bin/cosmalia-session-default
      cp $src/README.md $out/usr/share/doc/cosmalia-session/README.md
      cp $src/LICENSE $out/usr/share/licenses/cosmalia-session/LICENSE
      chmod +x $out/usr/bin/cosmalia-session-default $out/usr/bin/cosmalia-session
      patchShebangs $out/usr/bin

      # Fix the FHS paths for NixOS.
      sessionBin="$out/usr/bin/cosmalia-session"
      substituteInPlace "$sessionBin" ${allFlags}
      substituteInPlace $out/usr/bin/cosmalia-session-default \
        --replace '/usr/bin/cosmalia-session' "$sessionBin"
      substituteInPlace $out/usr/share/wayland-sessions/cosmalia.desktop \
        --replace '/usr/bin/cosmalia-session' "$sessionBin"
      for unit in $out/usr/lib/systemd/user/*; do
        substituteInPlace "$unit" ${unitFlags}
      done

      # FHS distros find user units in /usr/lib/systemd/user; NixOS finds them
      # in $XDG_DATA_DIRS/systemd/user, i.e. /run/current-system/sw/share/systemd/user.
      mkdir -p $out/share/systemd/user
      cp $out/usr/lib/systemd/user/* $out/share/systemd/user/

      # Two trees are intentional: the FHS layout (usr/bin, usr/share, ...) is
      # the shared source of truth for the Arch/Fedora packages, while the
      # Nix-standard layout (bin, share, lib) is what environment.systemPackages
      # links into /run/current-system/sw. Keep both in sync. Without the
      # mirror, wayland-sessions and xdg-desktop-portal are invisible on NixOS.
      mkdir -p $out/bin $out/share $out/lib
      cp -r $out/usr/bin/. $out/bin/
      cp -r $out/usr/share/. $out/share/
      cp -r $out/usr/lib/. $out/lib/

      runHook postInstall
    '';

    postInstall = ''
      test -f $out/usr/bin/cosmalia-session
      test -f $out/usr/share/wayland-sessions/cosmalia.desktop
      test -f $out/usr/share/xdg-desktop-portal/cosmalia-portals.conf
      test -f $out/usr/lib/systemd/user/cosmalia-session.target
      test -f $out/usr/lib/systemd/user/noctalia.service
      test -f $out/usr/lib/systemd/user/cosmic-settings-daemon.service
      test -f $out/usr/bin/cosmalia-session-default
      test -f $out/share/systemd/user/noctalia.service
      test -f $out/bin/cosmalia-session
      test -f $out/share/wayland-sessions/cosmalia.desktop
      test -f $out/share/xdg-desktop-portal/cosmalia-portals.conf

      # No FHS absolute paths should survive in the installed files
      # (store paths contain "/usr/bin/" too, so only match FHS-style uses).
      ! grep -Rq -E '(^|[= ])/usr/bin/' \
        $out/usr/bin $out/usr/lib/systemd/user $out/usr/share/wayland-sessions
    '';

    doCheck = false;
    dontStrip = true;
  }
