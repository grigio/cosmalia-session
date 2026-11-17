{
  config,
  lib,
  pkgs,
  cosmaliaSessionFlake,
  ...
}: let
  cfg = config.services.cosmalia-session;
  cosmaliaPkg = cfg.package;
in {
  options.services.cosmalia-session = {
    enable = lib.mkEnableOption "Cosmalia session (minimal COSMIC desktop with cosmic-comp-traffic and Noctalia)";

    package = lib.mkOption {
      type = lib.types.package;
      default = cosmaliaSessionFlake.packages.${pkgs.stdenv.hostPlatform.system}.cosmalia-session;
      defaultText = lib.literalExpression "cosmalia-session.packages.<system>.cosmalia-session";
      description = "The Cosmalia session package to use.";
    };

    # Whether to make Cosmalia the default greeter session
    defaultSession = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Make Cosmalia the default session in the greeter (requires greetd).";
    };

    # Additional packages to add to the session environment
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional packages to include in the session environment.";
    };

    # Enable XWayland support (default: disabled for security/resource usage)
    enableXWayland = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable XWayland support in the session (sets COSMALIA_NO_XWAYLAND=0).";
    };
  };

  config = lib.mkIf cfg.enable {
    # The package ships the session launcher, the wayland-sessions .desktop
    # file and the systemd user units.
    environment.systemPackages = [cosmaliaPkg] ++ cfg.extraPackages;

    # Expose the XDG session entry to display managers (greetd uses the
    # command above, but SDDM/GDM/etc. scan share/wayland-sessions).
    environment.pathsToLink = ["/share/wayland-sessions"];

    # Make greetd launch Cosmalia directly (greetd needs a command, not a
    # session .desktop file).
    services.greetd = lib.mkIf cfg.defaultSession {
      enable = true;
      settings.default_session = {
        command = "${cosmaliaPkg}/usr/bin/cosmalia-session";
        user = "greeter";
      };
    };

    # The launcher turns XWayland off by default; let the option flip it.
    environment.sessionVariables = lib.mkIf cfg.enableXWayland {
      COSMALIA_NO_XWAYLAND = "0";
    };

    # Ensure required services are available. The session launcher restarts
    # the portal backends with the correct WAYLAND_DISPLAY on every login.
    services.pipewire = {
      enable = true;
      wireplumber.enable = true;
      pulse.enable = true;
    };

    security.polkit.enable = true;

    services.gnome.gnome-keyring.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-wlr
        xdg-desktop-portal-cosmic
        xdg-desktop-portal-gnome
      ];
      # The package's cosmalia-portals.conf is also on the system path; set
      # it here as well so the backend choice is explicit on NixOS.
      config.cosmalia = {
        default = ["wlr" "gtk"];
        "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
        "org.freedesktop.impl.portal.ScreenCast" = ["wlr"];
        "org.freedesktop.impl.portal.Screenshot" = ["wlr"];
        "org.freedesktop.impl.portal.Secret" = ["gnome-keyring"];
        # GNOME Snapshot (and other Camera portal users) need the GNOME
        # backend; the GTK/wlr backends do not implement Camera.
        "org.freedesktop.impl.portal.Camera" = ["gnome"];
        "org.freedesktop.impl.portal.Notification" = [];
        "org.freedesktop.impl.portal.Clipboard" = [];
        "org.freedesktop.impl.portal.GlobalShortcuts" = [];
        "org.freedesktop.impl.portal.InputCapture" = [];
        "org.freedesktop.impl.portal.Usb" = [];
        "org.freedesktop.impl.portal.Inhibit" = [];
      };
    };

    systemd.user.services.xdg-desktop-portal.wantedBy = ["graphical-session.target"];
  };
}
