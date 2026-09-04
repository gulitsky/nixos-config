{
  config,
  lib,
  ...
}:
let
  cfg = config.my.secrets;
in
{
  options.my.secrets.enable = lib.mkEnableOption "секреты через sops-nix";

  # Выключено на время установки: sops-install-secrets запускается в
  # activation и падает, если secrets/secrets.yaml ещё не зашифрован
  # настоящими ключами. Падение activation = неустановившаяся система.
  config = lib.mkIf cfg.enable {
    sops = {
      defaultSopsFile = ../../../secrets/secrets.yaml;

      # age-ключ выводится из ssh host key. Он лежит в /persist/etc/ssh,
      # поэтому /persist обязан монтироваться до активации (neededForBoot).
      #
      # keyFile здесь НЕ задаём: при generateKey = false sops-nix считает,
      # что файл уже существует, и падает в activation, если его нет.
      # А generateKey = true был бы ещё хуже: /var/lib/sops-nix не в списке
      # persist, ключ пересоздавался бы каждую загрузку с новым отпечатком,
      # которого нет в .sops.yaml. sshKeyPaths самодостаточен.
      age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];

      secrets."users/${config.my.username}" = {
        # Кладётся в /run/secrets-for-users до создания пользователей.
        neededForUsers = true;
      };

      # Личный ssh-ключ, перенесённый со старой машины. Лежит в
      # /run/secrets/ssh/andrey_ed25519, а НЕ в ~/.ssh: домашний каталог —
      # bind-mount impermanence, и симлинк, который sops кладёт по своему
      # `path`, рискует лечь в tmpfs до монтирования /persist. Путь до ключа
      # ssh получает из home/andrey/ssh.nix через osConfig.
      secrets."ssh/${config.my.username}_ed25519" = {
        owner = config.my.username;
        # ssh отказывается брать ключ, доступный кому-то ещё.
        mode = "0400";
      };

      # Список личных хостов: адреса, порты и логины — тоже то, что не должно
      # уезжать в публичный git. Файл в формате ssh_config целиком, ssh
      # подключает его через Include (см. home/andrey/ssh.nix).
      secrets."ssh/config" = {
        owner = config.my.username;
        mode = "0400";
      };
    };
  };
}
