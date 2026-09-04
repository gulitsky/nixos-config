{
  networking.networkmanager = {
    enable = true;
    # Суппликант, а не менеджер соединений: профили, VPN, ModemManager и
    # per-connection DNS в resolved остаются за NM. iwd на iwlwifi быстрее
    # коннектится после resume и аккуратнее роумит между AP (802.11r/k/v),
    # чего от wpa_supplicant годами не удаётся добиться.
    # Цена: у связки NM+iwd урезан 802.1X (часть EAP-методов требует
    # provisioning-файлов iwd, а не профиля NM) и хуже AP-режим для hotspot.
    # Откат — вернуть "wpa_supplicant"; состояние NM при этом не теряется.
    wifi.backend = "iwd";
  };
  networking.firewall.enable = true;

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "allow-downgrade";
      DNSOverTLS = "opportunistic";
    };
  };
}
