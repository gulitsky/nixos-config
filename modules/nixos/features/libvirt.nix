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
