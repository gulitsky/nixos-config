{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.libvirt;
in
{
  options.my.libvirt.enable = lib.mkEnableOption "libvirt/QEMU и virt-manager для десктопных VM";

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;

      qemu = {
        # Дефолт опции — полный pkgs.qemu со всеми чужими архитектурами.
        # Эмулировать aarch64 на ноуте незачем, а замыкание заметно толще.
        package = pkgs.qemu_kvm;

        # Windows 11 без TPM 2.0 не ставится; swtpm даёт эмулированный, его
        # состояние libvirt держит в /var/lib/libvirt/swtpm (в persist).
        swtpm.enable = true;
      };
    };

    # OVMF отдельным пакетом не подключаем, хотя все гайды старше года учат
    # `qemu.ovmf.packages = [ pkgs.OVMFFull.fd ]`: этот подсубмодуль из nixpkgs
    # удалён и на него стоит assertion. Все образы прошивки, включая
    # secure-boot вариант для Windows 11, приезжают вместе с QEMU.

    # swtpm выпускает виртуальному TPM сертификаты EK и platform через свой
    # локальный CA, а ключ этого CA держит в /var/lib/swtpm-localca. Каталог не
    # создаёт никто: libvirt запускает swtpm от пользователя tss, а тот не может
    # сделать mkdir в /var/lib. Итог — создание домена падает на swtpm_setup с
    # exitstatus 1, а настоящая причина видна только в /var/log/swtpm (доступном
    # одному root): «Could not create directory for statedir».
    systemd.tmpfiles.rules = [ "d /var/lib/swtpm-localca 0750 tss tss -" ];

    # Пользователя tss заводит security.tpm2 — он включён ради разблокировки
    # диска по TPM. Если это когда-нибудь разъедется, лучше упасть на
    # вычислении, чем на первом создании виртуалки.
    assertions = [
      {
        assertion = config.users.users ? tss;
        message = "my.libvirt: swtpm работает от пользователя tss, его заводит security.tpm2.";
      }
    ];

    programs.virt-manager.enable = true;
    users.users.${config.my.username}.extraGroups = [ "libvirtd" ];

    # Проброс Рутокена в гостя прямо из virt-manager, без прав root. Хелпер
    # ставится setuid и даёт непривилегированному пользователю доступ к USB
    # вообще, не только к токену; на однопользовательском ноуте это приемлемо,
    # но знать стоит. Альтернатива — <hostdev> по 0a89:0025 в XML домена.
    virtualisation.spiceUSBRedirection.enable = true;

    # pkgs.virtio-win в systemPackages не кладём: пакет распакован в корень
    # выхода, и в системный профиль уехали бы каталоги вроде amd64/ и viostor/.
    # ISO для установщика собирается из него по требованию — `just virtio-iso`.
  };
}
