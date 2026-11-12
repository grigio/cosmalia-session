{ pkgs, cosmalia-session, lib, ... }:

let
  cfg = config.services.cosmalia-session;
in
{
  options.services.cosmalia-session = {
    enable = lib.mkEnableOption "Cosmalia session (minimal COSMIC desktop with cosmic-comp and Noctalia)";

    # Whether to make Cosmalia the default greeter session
    defaultSession = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Make Cosmalia the default session in the greeter (requires greetd with gtkgreet)";
    };

    # Additional packages to add to the session environment
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to include in the session environment";
    };

    # Enable XWayland support (default: disabled for security/resource usage)
    enableXWayland = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable XWayland support in the session (set COSMALIA_NO_XWAYLAND=0)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Environment setup for the session
    environment.systemPackages = [ cosmalia-session ] ++ cfg.extraPackages;

    # Ensure greetd is installed if using default session
    services.greetd = lib.mkIf cfg.defaultSession {
      enable = true;
      defaultSession = {
        command = "cosmalia-session";
        user = "greeter";
      };
    };

    # Set up systemd user services for the session
    systemd.user.services.cosmalia-session = {
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
    } // lib.mkIf cfg.enableXWayland {
      environment = {
        COSMALIA_NO_XWAYLAND = "0";
      };
    };

    # Ensure required services are available
    # These are typically provided by the dependencies of cosmalia-session
    # but we document them here for completeness
    services.pipewire = {
      enable = true;
      wireplumber.enable = true;
      pulse.enable = true;
    };

    # Ensure polkit is available
    services.polkit.enable = true;

    # GNOME keyring for secret service
    programs.gnome-keyring = {
      enable = true;
      startLoginComponents = true;
    };

    # XDG desktop portal configuration
    # The cosmalia-portals.conf from the package handles portal selection
    # but we ensure the portal service is running
    systemd.user.services.xdg-desktop-portal = {
      wantedBy = [ "graphical-session.target" ];
    };

    # Home-manager compatible configuration
    # (if using home-manager, these can be managed there instead)
    xdg.desktopPortal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gnome pkgs.xdg-desktop-portal-wlr ];
    };

    # Session-specific environment variables
    environment.variables = {
      XDG_CURRENT_DESKTOP = "cosmalia:COSMIC";
      XDG_SESSION_DESKTOP = "cosmalia";
    };

    # Documentation
    services.cosmalia-session.documentation = lib.mkIf cfg.enable {
      enable = true;
    };
  };
}