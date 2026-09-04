{
  config,
  inputs,
  pkgs,
  ...
}:
{
  # fish должен быть включён на уровне системы, иначе его нет в /etc/shells
  # и chsh/login его не примут. Конфигурация — в home-manager.
  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;

  # Root без пароля: логин только через sudo/su от пользователя.
  users.mutableUsers = false;

  users.users.${config.my.username} = {
    isNormalUser = true;
    description = "Andrey";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
    ];
    # Пароль приезжает из sops (features/secrets.nix), файл лежит в
    # /run/secrets-for-users (secret объявлен с neededForUsers = true,
    # иначе он появляется уже после создания пользователей).
    hashedPasswordFile = config.sops.secrets."users/${config.my.username}".path;
    # На новой машине, где sops ещё не настроен, — закомментировать строку
    # выше и раскомментировать эту (`mkpasswd -m sha-512`). Держать обе
    # одновременно нельзя: при mutableUsers = false initialHashedPassword
    # уезжает в hashedPassword, и NixOS ругается на неоднозначность.
    # initialHashedPassword = "$6$...";
    openssh.authorizedKeys.keys = [
      # Раскомментировать, чтобы пускать на ноут по ssh с этим ключом
      # (сейчас sshd слушает, но авторизованных ключей нет — войти нельзя).
      # Тот же ключ ноут использует как клиент, см. home/andrey/ssh.nix.
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJbTw5Gmx4gKGaW4X4QqyHqLo2ueU75qyB+HRkjwgyOG andrey@cameo"
    ];
  };

  security.sudo.execWheelOnly = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    extraSpecialArgs = { inherit inputs; };
    users.${config.my.username} = import ../../../home/andrey;
  };
}
