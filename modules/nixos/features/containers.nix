{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.containers;
in
{
  options.my.containers.enable = lib.mkEnableOption "podman в rootless-режиме";

  config = lib.mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;

      # `docker` как алиас podman: половина README в интернете и почти
      # каждый Makefile зовут именно docker. Настоящего docker в системе
      # нет, так что за сокет и имя команды бороться некому.
      dockerCompat = true;

      # Без этого контейнеры в пользовательской сети не резолвят друг
      # друга по имени, и всё compose-подобное разваливается.
      defaultNetwork.settings.dns_enabled = true;
    };

    # `podman compose` (а значит и `docker compose`) уходит во внешний провайдер.
    # Провайдер задан на уровне системы, а не проектного devShell, потому что
    # ту же команду печатают git-хуки и неинтерактивные шеллы агентов — они
    # никакого devShell не видели.
    virtualisation.containers.containersConf.settings.engine = {
      compose_providers = [ "${pkgs.docker-compose}/bin/docker-compose" ];
      compose_warning_logs = false;
    };

    # Rootless-podman держит образы в ~/.local/share/containers, а этот
    # каталог уже персистится в features/impermanence.nix. Rootful со своим
    # /var/lib/containers сознательно не заводим: на ноуте он не нужен,
    # а персистить пришлось бы отдельно.

    environment.systemPackages = with pkgs; [
      # Настоящий docker/compose вместо podman-compose: питоновая реализация не
      # держит depends_on/condition: service_healthy и `compose run --rm` в том
      # виде, в котором их используют compose-файлы проектов, и молча деградирует.
      docker-compose
    ];
  };
}
