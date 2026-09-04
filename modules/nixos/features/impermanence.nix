{
  config,
  lib,
  ...
}:
let
  cfg = config.my.impermanence;
in
{
  options.my.impermanence.enable = lib.mkEnableOption "эфемерный root на tmpfs";

  config = lib.mkIf cfg.enable {
    # tmpfs-root требует systemd в initrd (и он же нужен для TPM2-unlock).
    boot.initrd.systemd.enable = true;

    # Без этого sops-nix и users.hashedPasswordFile не увидят /persist.
    fileSystems."/persist".neededForBoot = true;

    environment.persistence."/persist" = {
      # Не показывать десятки bind-mount'ов в `mount` и в файловых
      # менеджерах — иначе список «мест» в GTK превращается в помойку.
      hideMounts = true;

      directories = [
        "/etc/NetworkManager/system-connections"
        "/etc/nixos"
        "/etc/ssh"
        "/var/lib/bluetooth"
        "/var/lib/fprint"
        "/var/lib/nixos" # uid/gid маппинги — иначе они поедут после reboot
        "/var/lib/sbctl" # ключи Secure Boot
        "/var/lib/pcrlock.d" # измерения systemd-pcrlock (my.secureboot.measuredBoot)
        "/var/lib/systemd"
        "/var/lib/upower"
        {
          # tuigreet --remember: иначе каждый boot просит логин заново.
          directory = "/var/cache/tuigreet";
          user = "greeter";
          group = "greeter";
          mode = "0755";
        }
      ];

      files = [
        # machine-id обязателен: без него journald теряет историю между
        # загрузками. Работает потому, что NixOS выполняет activation
        # (а с ней и bind-mount'ы impermanence) в stage-2 ДО запуска systemd.
        "/etc/machine-id"
        "/etc/adjtime"
      ];

      users.${config.my.username} = {
        # Пути относительно $HOME.
        directories = [
          ".config"
          ".local/share"
          ".local/state"
          # Кеши тулчейнов, которые иначе качаются заново каждую загрузку: колёса
          # uv (его читает uv sync в бэкенде) и tarball pnpm, который тянет corepack.
          ".cache/uv"
          ".cache/node"
          # История запусков elephant: без неё walker после каждой загрузки
          # ранжирует приложения с нуля и «забывает» частые.
          ".cache/elephant"
          ".gnupg"
          # Логин Claude Code (.credentials.json) и история сессий.
          ".claude"
          "Documents"
          "Downloads"
          "Projects"
          {
            directory = ".ssh";
            mode = "0700";
          }
        ];
        files = [
          ".bash_history"
          # Настройки и список проектов Claude Code — отдельный файл рядом с ~/.
          ".claude.json"
        ];
      };
    };

    # /var/log живёт на своём btrfs-сабволюме, а не в tmpfs.
    services.journald.storage = "persistent";
  };
}
