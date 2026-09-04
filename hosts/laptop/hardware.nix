{ lib, ... }:
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
