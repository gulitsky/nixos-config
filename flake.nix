{
  description = "My NixOS configuration.";

  nixConfig = {
    extra-experimental-features = "nix-command flakes";
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
    ];
  };

  inputs = {
    nixos.url = "github:nixos/nixpkgs/nixos-23.05";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixlib.url = "github:nix-community/nixpkgs.lib";
    nixos-hardware.url ="github:nixos/nixos-hardware";

    flake-compat.url = "github:nix-community/flake-compat";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixlib";
    };

    disko {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    impermanence.url = "github:nix-community/impermanence";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs = {
        nixlib.follows = "nixlib";
        nixpkgs.follows = "nixos-unstable";
      };
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixos-unstable";
      };
    };

    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixos-unstable";
        nixpkgs-stable.follows = "nixos";
      }
    };

    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs = {
        nixpkgs.follows = "nixos-unstable";
        flake-compat.follows = "flake-compat";
      }
    };
  };

  outputs = { self, flake-parts, flake-utils, ... } @ inputs:
    flake-parts.lib.mkFlake {
      inherit self inputs;

      systems = with flake-utils.lib.systems; [
        x86_64-linux
        aarch64-linux
      ];
    };
}
