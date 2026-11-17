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

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    cosmic-comp-traffic,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];

    # Single source of truth for the release version. CI checks that this
    # matches the git tag being released and that the package picks it up.
    version = nixpkgs.lib.strings.trim (builtins.readFile ./VERSION);

    # Resolve the package for the caller's system, not for whichever system
    # happened to evaluate this flake. `builtins.currentSystem` is impure
    # and produces the wrong package on remote/cross builds.
    overlays.default = final: prev: {
      cosmalia-session = self.packages.${final.system}.cosmalia-session;
    };

    # NixOS modules are system independent. Inject the flake into the
    # module through `_module.args`; the module then selects the right
    # package using its own `pkgs.system`.
    nixosModules.cosmalia-session = {
      imports = [./modules/cosmalia-session.nix];
      _module.args.cosmaliaSessionFlake = self;
    };

    # Boots a VM and asserts the package files, units and greetd wiring really
    # land in the system (the module-check below only proves evaluation).
    nixosTests.cosmalia-session = import ./tests/nixos/cosmalia-session.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inherit nixosModules;
    };
  in
    flake-utils.lib.eachSystem systems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};

        # The derivation only needs the runtime files, scripts and docs.
        # cleanSourceWith drops build metadata and the large docs/ images from
        # the build input instead of copying them into every derivation.
        repo-src = nixpkgs.lib.cleanSourceWith {
          src = self;
          filter = path: type: let
            base = baseNameOf path;
          in
            base
            != "packages"
            && base != "modules"
            && base != ".git"
            && base != "flake.lock"
            && base != "docs"
            && base != "result"
            && base != "tests";
        };

        cosmalia-session = pkgs.callPackage ./packages/cosmalia-session.nix {
          inherit version;
          src = repo-src;
          cosmic-comp = cosmic-comp-traffic.packages.${system}.default;
        };

        # Force a full NixOS module evaluation at check time so that broken
        # options / module arguments are caught by `nix flake check`.
        module-check = let
          eval = nixpkgs.lib.nixosSystem {
            modules = [
              {nixpkgs.hostPlatform = system;}
              nixosModules.cosmalia-session
              ({...}: {services.cosmalia-session.enable = true;})
            ];
          };
        in
          pkgs.runCommand "check-cosmalia-session-module" {} ''
            test -n "${eval.config.services.cosmalia-session.package.name}"
            echo ok > $out
          '';
      in {
        packages = {
          inherit cosmalia-session;
          default = cosmalia-session;
        };

        # `nix develop github:grigio/cosmalia-session` (documented in README)
        devShells.default = pkgs.mkShell {
          inputsFrom = [cosmalia-session];
          packages = with pkgs; [alejandra statix];
        };

        checks =
          {
            inherit cosmalia-session module-check;
          }
          // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
            nixos-cosmalia-session = nixosTests.cosmalia-session;
          };

        formatter = pkgs.alejandra;
      }
    )
    // {
      inherit overlays nixosModules nixosTests;
    };
}
