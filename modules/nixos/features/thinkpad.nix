{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.thinkpad;
in
{
  options.my.thinkpad = {
    enable = lib.mkEnableOption "ThinkPad-специфика (thinkpad_acpi)";

    chargeThresholds = {
      start = lib.mkOption {
        type = lib.types.ints.between 0 99;
        default = 75;
        description = "Ниже этого процента начинается зарядка.";
      };
      stop = lib.mkOption {
        type = lib.types.ints.between 1 100;
        default = 80;
        description = ''
          На этом проценте зарядка прекращается. 80/75 — заметно продлевает
          жизнь батарее при работе от розетки. Перед поездкой сними лимит:
          sudo systemctl stop thinkpad-charge-thresholds
          echo 100 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Управление вентилятором и hotkeys.
    boot.extraModprobeConfig = ''
      options thinkpad_acpi fan_control=1
    '';

    environment.systemPackages = with pkgs; [
      acpi
      lm_sensors
    ];

    # TrackPoint. По умолчанию ускорение вялое.
    hardware.trackpoint = {
      enable = true;
      emulateWheel = true; # средняя кнопка + TrackPoint = скролл
      speed = 120;
      sensitivity = 200;
    };

    # Пороги заряда. Отдельный юнит, а не TLP: TLP конфликтует с
    # power-profiles-daemon, который управляет platform_profile.
    systemd.services.thinkpad-charge-thresholds = {
      description = "ThinkPad battery charge thresholds";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        bat=/sys/class/power_supply/BAT0
        [ -w "$bat/charge_control_start_threshold" ] || exit 0
        echo ${toString cfg.chargeThresholds.start} > "$bat/charge_control_start_threshold"
        echo ${toString cfg.chargeThresholds.stop}  > "$bat/charge_control_end_threshold"
      '';
    };

    # Отпечаток. У T14 Gen1 сканер Synaptics; часть ревизий libfprint
    # не поддерживает вообще (нужен закрытый python-validity, которого в
    # nixpkgs нет). Проверь: `lsusb | grep -i synaptics` и fprintd-enroll.
    services.fprintd.enable = lib.mkDefault false;
  };
}
