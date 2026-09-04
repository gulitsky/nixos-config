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
  options.my.profiles.laptop = {
    enable = lib.mkEnableOption "профиль ноутбука";

    scx = {
      enable = lib.mkEnableOption ''
        sched_ext: планировщик из userspace вместо штатного EEVDF.
        Ядро nixpkgs собрано с CONFIG_SCHED_CLASS_EXT=y, так что менять
        kernelPackages (linux_zen/xanmod/cachyos) ради BORE-подобного
        поведения не нужно — оно и есть главное, что те ядра дают
      '';

      scheduler = lib.mkOption {
        type = lib.types.str;
        default = "scx_lavd";
        description = ''
          Какой планировщик грузить. lavd (latency-aware virtual deadline)
          заточен под интерактив на машинах с одним CPU-комплексом — то есть
          ровно случай Renoir. Альтернативы: scx_bpfland (похож, консервативнее),
          scx_flash (дедлайны, ровнее под нагрузкой), scx_rusty (многоузловой,
          тут смысла нет). Список валидных значений задаёт `services.scx.scheduler`.
        '';
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "--autopower" ];
        description = ''
          Аргументы планировщику. `--autopower` у lavd переключает
          performance/balanced/powersave по активному профилю
          power-profiles-daemon — поэтому он и стоит по умолчанию: смена
          профиля в GUI начинает влиять и на планировщик. Без него lavd
          всегда в balanced. Флаги у планировщиков разные и несовместимые:
          при смене `scheduler` перечитай `<sched> --help`.
        '';
      };
    };
  };

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

    assertions = lib.optionals cfg.scx.enable [
      {
        assertion = lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.12";
        message = "my.profiles.laptop.scx требует ядро >= 6.12: sched_ext появился там.";
      }
    ];

    # Планировщик из userspace. Если юнит упал, ядро откатывается на EEVDF
    # и система продолжает работать: `systemctl status scx`,
    # `cat /sys/kernel/sched_ext/state`.
    # package намеренно дефолтный (scx.full): в нём и rust-, и C-планировщики,
    # так что смена `scheduler` не требует трогать ещё и пакет.
    services.scx = lib.mkIf cfg.scx.enable {
      enable = true;
      inherit (cfg.scx) scheduler extraArgs;
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
