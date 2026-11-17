{
  pkgs,
  nixosModules,
  ...
}:
pkgs.testers.runNixOSTest {
  name = "cosmalia-session";

  nodes.machine = {
    imports = [nixosModules.cosmalia-session];
    services.cosmalia-session.enable = true;
    system.stateVersion = "26.11";
  };

  # A second node verifies that defaultSession wires greetd correctly.
  nodes.greeter = {
    imports = [nixosModules.cosmalia-session];
    services.cosmalia-session = {
      enable = true;
      defaultSession = true;
      enableXWayland = true;
    };
    system.stateVersion = "26.11";
  };

  testScript = ''
    import re

    machine.wait_for_unit("multi-user.target")

    # Package files must be linked into the system path, including the two
    # trees that are easy to miss: wayland-sessions and xdg-desktop-portal.
    machine.succeed("test -x /run/current-system/sw/bin/cosmalia-session")
    machine.succeed("test -x /run/current-system/sw/bin/cosmalia-session-default")
    machine.succeed("test -f /run/current-system/sw/share/wayland-sessions/cosmalia.desktop")
    machine.succeed("test -f /run/current-system/sw/share/xdg-desktop-portal/cosmalia-portals.conf")
    for unit in [
        "cosmalia-session.target",
        "noctalia.service",
        "cosmic-settings-daemon.service",
    ]:
        machine.succeed(f"test -f /run/current-system/sw/share/systemd/user/{unit}")

    # The launcher must resolve all binaries to store paths, never /usr/bin.
    launcher = machine.succeed("cat /run/current-system/sw/bin/cosmalia-session")
    assert not re.search(r"(^|[= ])/usr/bin/", launcher), "launcher still has FHS paths"
    assert "XCURSOR_THEME" in launcher, "launcher does not set the cursor theme"
    # Every absolute binary path in the launcher must actually exist. This
    # catches wrong package substitutions (e.g. dbus-update-activation-
    # environment living in dbus, not systemd).
    import os
    for token in re.findall(r"/nix/store/[^\s\"'|;$]+?/bin/[a-zA-Z0-9._-]+", launcher):
        assert os.path.exists(token), f"launcher references missing file: {token}"

    # Portal config is installed with Camera support for GNOME Snapshot.
    portal = machine.succeed(
        "cat /run/current-system/sw/share/xdg-desktop-portal/cosmalia-portals.conf"
    )
    assert "org.freedesktop.impl.portal.ScreenCast=wlr" in portal
    # The NixOS module generates a higher-precedence /etc/xdg config that adds
    # the Camera backend for GNOME Snapshot.
    nixos_portal = machine.succeed(
        "cat /etc/xdg/xdg-desktop-portal/cosmalia-portals.conf"
    )
    assert "org.freedesktop.impl.portal.Camera=gnome" in nixos_portal

    # Supporting services are pulled in by the module. In a headless VM some
    # of their units get masked, so assert the binaries are present instead.
    for binary in ["pipewire", "wpctl", "pkcheck", "gnome-keyring-daemon"]:
        machine.succeed(f"command -v {binary}")

    # defaultSession=true points greetd at the cosmalia launcher.
    greeter.wait_for_unit("greetd.service")
    exec_start = greeter.succeed("systemctl show greetd.service -p ExecStart --value")
    match = re.search(r"/nix/store/[^ ]*greetd\.toml", exec_start)
    assert match is not None, f"no greetd.toml in ExecStart: {exec_start}"
    greeter.succeed(f"grep -q cosmalia-session {match.group(0)}")
  '';
}
