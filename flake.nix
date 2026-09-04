{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    impermanence.url = "github:nix-community/impermanence";

    lanzaboote.url = "github:nix-community/lanzaboote";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # Fresh IDE: терминальный редактор на Rust, в nixpkgs его нет.
    fresh.url = "github:sinelaw/fresh";
    fresh.inputs.nixpkgs.follows = "nixpkgs";

    # Helium: браузера нет в nixpkgs.
    helium.url = "github:oxcl/nix-flake-helium-browser";
    helium.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.treefmt-nix.flakeModule ];
      systems = [ "x86_64-linux" ];

      perSystem =
        { pkgs, system, ... }:
        {
          # Свои пакеты доступны и в devShell, и в системе — через один оверлей.
          _module.args.pkgs = import nixpkgs {
            inherit system;
            overlays = import ./overlays inputs;
            config.allowUnfree = true;
          };

          treefmt = import ./treefmt.nix;

          packages.helium = pkgs.helium;

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              nh
              nvd
              nix-output-monitor
              sops
              age
              ssh-to-age
              # Два языковых сервера для nix намеренно: nil быстрый и умеет
              # rename, nixd умеет вычислять опции NixOS/home-manager.
              nil
              nixd
              statix
              deadnix
              just
              inputs.disko.packages.${system}.disko
            ];
          };

          # nix build .#installer-iso
          packages.installer-iso = inputs.self.nixosConfigurations.installer.config.system.build.isoImage;
        };

      flake.nixosConfigurations =
        let
          mkHost =
            hostName:
            nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs; };
              modules = [
                ./modules/nixos
                (./hosts + "/${hostName}")
                { networking.hostName = hostName; }

                inputs.disko.nixosModules.disko
                inputs.impermanence.nixosModules.impermanence
                inputs.lanzaboote.nixosModules.lanzaboote
                inputs.sops-nix.nixosModules.sops
                inputs.home-manager.nixosModules.home-manager
              ];
            };
        in
        {
          laptop = mkHost "laptop";

          # Установочная флешка с вшитым конфигом. Не хост, а сборочная цель.
          installer = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [ ./installer ];
          };
        };
    };
}
