{ inputs, ... }:
{
  imports = [
    # ВАЖНО: сверь имя атрибута перед первой сборкой:
    #   nix flake show github:NixOS/nixos-hardware | grep -i t14
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen1
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd

    ./disko.nix
    ./hardware.nix
  ];

  my = {
    username = "andrey";
    containers.enable = true;
    impermanence.enable = true;
    secrets.enable = true; # secrets/secrets.yaml зашифрован (шаг 4)
    secureboot = {
      enable = true; # шаг 6: сначала Setup Mode + sbctl create-keys
      tpm2Unlock.enable = true; # шаг 7: сначала systemd-cryptenroll
      measuredBoot.enable = false; # шаг 8, опционально: политика PCR 0/4/7
    };
    profiles.laptop.enable = true;
    profiles.niri.enable = true;
    thinkpad.enable = true;
  };
}
