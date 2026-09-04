{ lib, pkgs, ... }:
{
  # ThinkPad T14 Gen 1 (AMD), 20UD/20UE — Ryzen 5 PRO 4650U «Renoir», Vega iGPU.
  # Проверь список модулей после установки:
  #   nixos-generate-config --show-hardware-config
  # или замени файл на nixos-facter (см. README).
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
    # thunderbolt тут НЕ нужен: у AMD-версии T14 Gen1 нет Thunderbolt,
    # только USB4-less USB-C. У Intel-версии — нужен.
  ];
  boot.kernelModules = [ "kvm-amd" ];

  # Свежий mainline вместо дефолтного 6.18 LTS. Проверено на linux-config-7.2.2:
  # SCHED_CLASS_EXT=y (нужно для my.profiles.laptop.scx), HZ=1000, PREEMPT_LAZY=y —
  # то есть всё, за чем обычно идут в linux_zen, тут уже есть, а amdgpu новее.
  #
  # Плата: атрибут не пинует версию, `nix flake update` может увести ядро на
  # следующий мажор. Если после обновления на Renoir полезли артефакты на eDP —
  # раскомментируй amdgpu.dcdebugmask ниже; до выяснения грузись предыдущей
  # генерацией (их в меню держится 10, см. features/secureboot.nix).
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  boot.kernelParams = [
    # На Zen2-U даёт заметно лучший энергопрофиль, чем acpi-cpufreq.
    "amd_pstate=active"

    # Renoir + eDP: PSR (panel self refresh) вызывает мерцание/чёрные кадры
    # на части панелей T14 Gen1. Раскомментируй, если ловишь артефакты.
    # "amdgpu.dcdebugmask=0x10"
  ];

  services.xserver.videoDrivers = lib.mkDefault [ "amdgpu" ];

  # Intel AX200 (Wi-Fi 6). Агрессивный power save роняет пропускную
  # способность и добавляет лаги; выключаем, батарею это ест несильно.
  boot.extraModprobeConfig = ''
    options iwlwifi power_save=0
    options iwlmvm power_scheme=2
  '';

  # dTPM 2.0 на борту — нужен для systemd-cryptenroll (шаг 7 в README).
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };
}
