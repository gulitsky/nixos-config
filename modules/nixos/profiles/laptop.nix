{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.profiles.laptop;
in
{
  options.my.profiles.laptop.enable = lib.mkEnableOption "профиль ноутбука";

  config = lib.mkIf cfg.enable {
    # Питание: TLP конфликтует с power-profiles-daemon, выбираем ppd
    # (GNOME/KDE умеют им управлять из GUI).
    services.power-profiles-daemon.enable = true;
    services.thermald.enable = false; # Intel-only
    powerManagement.enable = true;

    services.upower.enable = true;
    services.fwupd.enable = true;

    # fprintd намеренно не трогаем здесь — им управляет
    # features/thinkpad.nix (у T14 Gen1 сканер проблемный).

    hardware.bluetooth = {
      enable = true;
      # true, а не false: клавиатура и мышь по bluetooth — основной ввод
      # в доке, с выключенным на старте радио их пришлось бы поднимать
      # руками через bluetoothctl после каждой загрузки.
      powerOnBoot = true;
    };

    # zram вместо swap-раздела. Hibernate при этом невозможен —
    # для него нужен настоящий swap внутри LUKS + resumeDevice.
    zramSwap = {
      enable = true;
      memoryPercent = 50;
    };

    environment.systemPackages = with pkgs; [
      brightnessctl
      powertop
    ];
  };
}
