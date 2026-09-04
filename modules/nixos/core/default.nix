{
  imports = [
    ./nix.nix
    ./locale.nix
    ./users.nix
    ./network.nix
  ];

  # Всё, что верно для любой машины и не имеет смысла выключать.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      # Дефолт модуля — true, а PAM пускает пароль ещё и через
      # keyboard-interactive, в обход PasswordAuthentication = false.
      KbdInteractiveAuthentication = false;
    };

    # Алиас на programs.ssh.knownHosts: пишет /etc/ssh/ssh_known_hosts на всю
    # систему, чтобы первый git clone не спрашивал про незнакомый хост.
    # Проверять/обновлять: ssh-keyscan -t ed25519 github.com
    knownHosts."github.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

    # Ключи живут в /persist, иначе они меняются каждый boot
    # и ломают sops-nix (см. features/secrets.nix).
    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  system.stateVersion = "25.11";
}
