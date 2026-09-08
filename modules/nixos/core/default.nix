{
  imports = [
    ./nix.nix
    ./locale.nix
    ./users.nix
    ./network.nix
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
    };

    knownHosts."github.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # Внешние диски и флешки обычно форматированы в Windows: без этого udisks
  # (и yazi-плагин поверх него) на них просто спотыкается. exfat в ядре есть,
  # ntfs приезжает драйвером; оба нужны только ради сменных носителей.
  boot.supportedFilesystems = {
    ntfs = true;
    exfat = true;
  };

  system.stateVersion = "25.11";
}
