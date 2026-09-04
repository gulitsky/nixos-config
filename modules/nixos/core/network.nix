{
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # systemd-resolved: DoT + нормальный кэш
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "allow-downgrade";
      DNSOverTLS = "opportunistic";
    };
  };
}
