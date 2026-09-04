{
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}:
let
  # Скрипт-обёртка вокруг disko + nixos-install, чтобы не вспоминать
  # флаги в 2 часа ночи с чужой клавиатуры.
  install-laptop = pkgs.writeShellApplication {
    name = "install-laptop";
    runtimeInputs = with pkgs; [
      gitMinimal
      nixos-install-tools
      util-linux
    ];
    text = ''
      set -euo pipefail

      HOST="''${1:-laptop}"
      SRC=/etc/nixos-config
      WORK=/root/os

      if [ ! -d "$WORK" ]; then
        echo ">> Копирую конфиг в $WORK (store read-only, а device правится руками)"
        cp -r "$SRC" "$WORK"
        chmod -R u+w "$WORK"
      fi

      echo
      echo ">> Диски:"
      lsblk -d -o NAME,SIZE,MODEL
      echo
      echo ">> Проверь device в $WORK/hosts/$HOST/disko.nix и нажми Enter."
      echo ">> ЭТО СОТРЁТ ДИСК ЦЕЛИКОМ."
      read -r _

      nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
        --mode disko --flake "$WORK#$HOST"

      nixos-install --flake "$WORK#$HOST" --no-root-passwd

      echo
      echo ">> Кладу конфиг в /persist, чтобы после первой загрузки он был под рукой"
      mkdir -p /mnt/persist/home/andrey/Projects/cameo
      cp -r "$WORK" /mnt/persist/home/andrey/Projects/cameo/os
      # Копировали root'ом; users.mutableUsers = false даёт andrey uid 1000.
      chown -R 1000:100 /mnt/persist/home/andrey
      echo ">> reboot, вынуть флешку."
    '';
  };
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    inputs.disko.nixosModules.disko
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Сам конфиг едет внутри ISO — на целевой машине не нужен ни интернет
  # для git clone, ни вторая флешка.
  environment.etc."nixos-config".source = inputs.self;

  environment.systemPackages = with pkgs; [
    install-laptop
    gitMinimal
    vim
    tmux
    pciutils
    usbutils
    inputs.disko.packages.x86_64-linux.disko
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Wi-Fi с установочной флешки: AX200 в T14 Gen1.
  hardware.enableRedistributableFirmware = true;
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false; # иначе конфликт с NM

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    # Вставь свой ключ, чтобы ставить по ssh, а не с клавиатуры ноута.
    # "ssh-ed25519 AAAA... andrey@wsl"
  ];
  # Пароль root не задаём: installation-cd уже даёт пустой пароль
  # для локальной консоли, а свой initialPassword конфликтует с ним
  # по приоритету и вызывает warning.

  # xz жмёт ISO минут двадцать; zstd — пару минут при +150 МБ размера.
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";
  # isoImage.isoName устарел; имя файла берётся из image.baseName.
  image.baseName = lib.mkForce "nixos-installer-t14";

  console.keyMap = "us";
  time.timeZone = "Europe/Moscow";
}
