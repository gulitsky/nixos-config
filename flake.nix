{
  description = "";

  nixConfig.extra-experimental-features = "nix-command flakes";

  inputs = {
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;

    nixlib.url = "github:nix-community/nixpkgs.lib";

    flake-utils.url = "github:numtide/flake-utils";

    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus";
    flake-utils-plus.inputs.flake-utils.follows = "flake-utils";

    nixos.url = "github:nixos/nixpkgs/nixos-22.05";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-hardware.url ="github:nixos/nixos-hardware";

    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs = "nixos";
    nixos-generators.inputs.nixlib = "nixlib";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixos";
    devshell.inputs.flake-utils.follows = "flake-utils";

    ragenix.url = "github:yaxitech/ragenix";
    ragenix.inputs.nixpkgs.follows = "nixos";
    ragenix.inputs.flake-utils.follows = "flake-utils";

    impermanence.url = "github:nix-community/impermanence";

    home-manager.url = "github:nix-community/home-manager/release-22.05";
    home-manager.inputs.nixpkgs.follows = "nixos";
    home-manager.inputs.utils.follows = "flake-utils";

    deploy.url = "github:serokell/deploy-rs";
    deploy.inputs.flake-compat.follows = "flake-compat";
    deploy.inputs.utils.follows = "flake-utils";
    deploy.inputs.nixpkgs.follows = "nixos";

    digga.url = "github:divnix/digga";
    digga.inputs.flake-compat.follows = "flake-compat";
    digga.inputs.utils.follows = "flake-utils";
    digga.inputs.nixpkgs.follows = "nixos";
    digga.inputs.latest.follows = "nixos-latest";
  };

  outputs = { self, digga, flake-utils, nixos, ... } @ inputs:
    digga.lib.mkFlake {
      inherit self inputs;

      supportedSystems = with flake-utils.lib.systems [
        x86_64-linux
        aarch64-linux
      ];

      channelsConfig.allowUnfree = true;

      sharedOverlays = [
        (final: prev: {
          __dontExport = true;
          lib = prev.lib.extend (lfinal: lprev): {
            our = self.lib;
          };
        })

        (import ./pkgs)
      ];

      channels = {
        nixos: {
          imports = [ (digga.lib.importOverlays ./overlays) ];
          overlays = [ ];
        };
        latest: { };
      };

      lib = import ./lib { lib = digga.lib // nixos.lib };
    };
}
