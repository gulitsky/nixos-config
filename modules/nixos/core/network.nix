{ pkgs, ... }:
{
  # Сеть держат два независимых демона вместо NetworkManager:
  #   iwd      — только wifi: аутентификация, роуминг (802.11r/k/v), autoconnect
  #              по своим known-networks в /var/lib/iwd;
  #   networkd — адресация: DHCP и IPv6 RA на всех интерфейсах, включая wlan0.
  # NM тут был лишним слоем: VPN, ModemManager и per-connection настройки не
  # используются, а его профили — императивное состояние, которое приходилось
  # персистить и которое умело плодить дубликаты («SSID», «SSID 1») при смене
  # имени интерфейса. Откат — networking.networkmanager.enable = true с
  # wifi.backend = "iwd"; known-networks iwd при этом переживают переключение.
  networking.wireless.iwd.enable = true;

  # EnableNetworkConfiguration у iwd намеренно не включаем: DHCP-клиент в
  # системе должен быть один. Иначе на wlan0 за адрес дерутся iwd и networkd.
  networking.useNetworkd = true;

  # networking.useDHCP оставлен в дефолтном true: он раскрывается в две
  # generic-сети networkd — "99-ethernet-default-dhcp" (Type=ether, то есть
  # и док, и USB-тетеринг с телефона) и "99-wireless-client-dhcp" (метрика
  # маршрута 1025, поэтому провод выигрывает у wifi, когда есть оба).
  # Он же включает --any у systemd-networkd-wait-online, иначе boot без дока
  # ждал бы поднятия enp* до таймаута.

  # Замена nmtui — impala: iwctl умеет всё то же, но сканирование и ввод
  # пароля в нём — три команды вместо списка сетей.
  environment.systemPackages = [ pkgs.impala ];

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "allow-downgrade";
      DNSOverTLS = "opportunistic";
    };
  };

  networking.firewall.enable = true;
}
