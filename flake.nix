{
  description = "Cosmalia — Minimal COSMIC desktop session";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    cosmic-comp-traffic = {
      url = "github:grigio/cosmic-comp-traffic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, cosmic-comp-traffic, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Get the repo source (excluding packages and modules directories)
        repo-src = builtins.filterSource (path: type: 
          baseNameOf path != "packages" && 
          baseNameOf path != "modules" &&
          baseNameOf path != ".git" &&
          baseNameOf path != "flake.lock"
        ) self;

        # Import the package with the repo source
        cosmalia-session = pkgs.callPackage ./packages/cosmalia-session.nix {
          src = repo-src;
          cosmic-comp = cosmic-comp-traffic.packages.${system}.default;
        };

        # Import the NixOS module
        nixosModule = import ./modules/cosmalia-session.nix {
          inherit pkgs cosmalia-session;
        };
      in
      {
        packages = {
          inherit cosmalia-session;
          default = cosmalia-session;
        };

        nixosModules = {
          cosmalia-session = nixosModule;
        };

        # Checks for CI
        checks = {
          inherit cosmalia-session;
        };
      }
    )
    // {
      # Provide an overlay for use in other flakes (single function, not per-system)
      overlays.default = final: prev: {
        cosmalia-session = self.packages.${builtins.currentSystem}.cosmalia-session;
      };
    };
}