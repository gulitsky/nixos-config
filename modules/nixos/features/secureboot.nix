{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.secureboot;
in
{
  options.my.secureboot = {
    enable = lib.mkEnableOption "Secure Boot через lanzaboote";

    tpm2Unlock = {
      enable = lib.mkEnableOption ''
        открывать LUKS токеном TPM2 (crypttab-опция `tpm2-device=auto`).
        Сам токен заводится вручную через systemd-cryptenroll — шаг 7 в README
      '';

      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "cryptroot" ];
        description = ''
          Имена томов из `boot.initrd.luks.devices` (здесь их объявляет disko).
        '';
      };
    };

    measuredBoot = {
      enable = lib.mkEnableOption ''
        Measured Boot: systemd-pcrlock заранее считает, какими станут PCR после
        обновления, и переписывает TPM-политику на каждый switch. Тогда TPM-токен
        LUKS не приходится перевыпускать после смены ядра/прошивки — шаг 8
      '';

      pcrs = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [
          4
          7
        ];
        description = ''
          Какие PCR запирает политика. 4 — вся загрузочная цепочка (stub, а через
          его хеши ядро, initrd и cmdline), 7 — состояние Secure Boot.

          0 (код прошивки) сюда не добавлен намеренно, хотя lanzaboote его умеет:
          он ломается на каждом обновлении прошивки, а fwupd тут включён. Из man
          systemd-pcrlock(8): перед обновлением надо вручную позвать
          `unlock-firmware-code`, после — `make-policy`; забыл ритуал — следующая
          загрузка попросит recovery-ключ. 1/2/3 «плавают» от настроек UEFI.
        '';
      };
    };
  };

  config = lib.mkMerge [
    {
      # Дефолт до перехода на lanzaboote: обычный systemd-boot.
      boot.loader.systemd-boot.enable = lib.mkDefault (!cfg.enable);
      boot.loader.efi.canTouchEfiVariables = true;

      # Больше 8 нельзя при measuredBoot: systemd-pcrlock не строит политику
      # на большее число вариантов (ассерт в модуле lanzaboote).
      # Само по себе lanzaboote места не просит: ядро и initrd оно кладёт в
      # EFI/nixos content-addressed (как и systemd-boot), поэтому генерации с
      # одним ядром делят файлы, а на генерацию приходится только подписанный
      # stub с cmdline и хешами — килобайты.
      boot.loader.systemd-boot.configurationLimit = if cfg.measuredBoot.enable then 8 else 10;

      # Разгребать NVRAM-записи UEFI (`efibootmgr -v`, `-b XXXX -B`).
      # Системный пакет, а не home: запускается только из-под root.
      # sbctl нужен ещё до включения флага (`create-keys` до первого switch:
      # без ключей lanzaboote нечем подписывать UKI и активация падает) и после
      # — как диагностика (`sbctl verify`, `sbctl status`).
      environment.systemPackages = [
        pkgs.efibootmgr
        pkgs.sbctl
        # chattr: ядро вешает immutable на переменные в efivarfs, и без снятия
        # флага `sbctl enroll-keys` не может перезаписать KEK и db. В закрытии
        # системы e2fsprogs и так есть, но не в PATH.
        pkgs.e2fsprogs
      ];
    }

    (lib.mkIf cfg.enable {
      # lanzaboote подменяет собой systemd-boot и подписывает UKI.
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };
    })

    (lib.mkIf cfg.tpm2Unlock.enable {
      assertions = [
        {
          assertion = config.boot.initrd.systemd.enable;
          message = "my.secureboot.tpm2Unlock требует systemd в initrd: TPM2-токен читает systemd-cryptsetup.";
        }
      ];

      # tpm2_getcap / tpm2_dictionarylockout — посмотреть и сбросить счётчик
      # anti-hammering, если PIN несколько раз ввели неверно и чип залочился.
      # tpm2_nvreadpublic / tpm2_nvundefine — разбирать NV-индексы чипа.
      environment.systemPackages = [ pkgs.tpm2-tools ];

      # Без явной опции systemd-cryptsetup не обязан пробовать TPM2-токен из
      # заголовка LUKS2 (crypttab(5), «Use the tpm2-device= option»). Пароль
      # остаётся рабочим фоллбэком, если TPM отказал.
      boot.initrd.luks.devices = lib.genAttrs cfg.tpm2Unlock.devices (_: {
        crypttabExtraOpts = [ "tpm2-device=auto" ];
      });
    })

    (lib.mkIf cfg.measuredBoot.enable {
      assertions = [
        {
          assertion = cfg.enable;
          message = "my.secureboot.measuredBoot без my.secureboot.enable бессмысленен: политику PCR 4 считает stub lanzaboote.";
        }
      ];

      boot.lanzaboote.measuredBoot = {
        enable = true;
        inherit (cfg.measuredBoot) pcrs;
      };
    })
  ];
}
