{
  description = "A highly structured configuration database.";

  nixConfig = {
    extra-experimental-features = "nix-command flakes";
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://nrdxp.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nrdxp.cachix.org-1:Fc5PSqY2Jm1TrWfm88l6cvGWwz3s93c6IOifQWnhNW4="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
    ];
  };

  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    nixlib.url = "github:nix-community/nixpkgs.lib";

    flake-utils.url = "github:numtide/flake-utils";
    flake-utils-plus = {
      url = "github:gytis-ivaskevicius/flake-utils-plus";
      inputs.flake-utils.follows = "flake-utils";
    };

    nixos.url = "github:nixos/nixpkgs/nixos-22.05";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url ="github:nixos/nixos-hardware";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs = {
        nixlib = "nixlib";
        nixpkgs = "nixos";
      };
    };

    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "nixos";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixos";
      };
    };

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixos";
      };
    };

    impermanence.url = "github:nix-community/impermanence";

    home-manager = {
      url = "github:nix-community/home-manager/release-22.05";
      inputs = {
        nixpkgs.follows = "nixos";
        utils.follows = "flake-utils";
      };
    };

    deploy = {
      url = "github:serokell/deploy-rs";
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixos";
        utils.follows = "flake-utils";
      };
    };

    digga = {
      url = "github:divnix/digga";
      inputs = {
        deploy.follows = "deploy";
        devshell.follows = "devshell";
        flake-compat.follows = "flake-compat";
        flake-utils-plus.follows = "flake-utils-plus";
        home-manager.follows = "home-manager";
        latest.follows = "nixos-unstable";
        nixlib.follows = "nixlib";
        nixpkgs-unstable.follows = "nixos-unstable";
        nixpkgs.follows = "nixos";
      };
    };

    nvfetcher = {
      url = "github:berberman/nvfetcher";
      inputs = {
        flake-compat.follows = "flake-compat";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixos";
      };
    };

    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.flake-utils.follows = "flake-utils";
    };

    stylix.url = "github:danth/stylix";
  };

  outputs = { self, deploy, devshell, digga, emacs-overlay, flake-utils, home-manager, impermanence, nixos, nixos-unstable, nvfetcher, ragenix, ... } @ inputs:
    digga.lib.mkFlake {
      inherit self inputs;

      supportedSystems = with flake-utils.lib.systems; [
        x86_64-linux
        aarch64-linux
      ];

      channelsConfig.allowUnfree = true;

      sharedOverlays = [
        (final: prev: {
          __dontExport = true;
          lib = prev.lib.extend (lfinal: lprev: {
            our = self.lib;
          });
        })

        emacs-overlay.overlay
        nvfetcher.overlay
        ragenix.overlay

        (import ./pkgs)
      ];

      channels = {
        nixos = {
          imports = [ (digga.lib.importOverlays ./overlays) ];
          overlays = [ ];
        };
        nixos-unstable = {
          imports = [ (digga.lib.importOverlays ./overlays) ];
          overlays = [ ];
        };
      };

      lib = import ./lib { lib = digga.lib // nixos.lib };

      nixos = {
        hostDefaults = {
          system = flake-utils.systems.x86_64-linux;
          channelName = "nixos";
          imports = [ (digga.lib.importExportableModules ./modules) ];
          modules = [
            { lib.our = self.lib; }
            digga.nixosModules.bootstrapIso
            digga.nixosModules.nixConfig
            home-manager.nixosModules.home-manager
            ragenix.nixosModules.age
            impermanence.nixosModules.impermanence
          ];
        };
      };
    };
}
