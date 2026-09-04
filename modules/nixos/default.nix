{ lib, ... }:
{
  imports = [
    ./core
    ./features/containers.nix
    ./features/impermanence.nix
    ./features/secureboot.nix
    ./features/secrets.nix
    ./features/thinkpad.nix
    ./profiles/laptop.nix
    ./profiles/niri.nix
  ];

  options.my = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "andrey";
      description = "Основной пользователь машины.";
    };
  };
}
