{ osConfig, ... }:
{
  programs.ssh = {
    enable = true;

    # Старые дефолты home-manager (ForwardAgent, ControlMaster, ...) объявлены
    # deprecated и при включённых сыплют варнингом на каждый switch. Отключаем
    # их и полагаемся на дефолты самого OpenSSH.
    enableDefaultConfig = false;

    # Личные хосты (адреса, порты, пользователи) в репозитории не лежат: их
    # блок целиком зашифрован в secrets/secrets.yaml и приезжает в
    # /run/secrets/ssh/config. Include рендерится первой строкой ~/.ssh/config,
    # то есть до `Host *` ниже, — а ssh для большинства директив берёт первое
    # найденное значение, так что хосты из секрета главнее.
    #
    # Заодно это единственный способ не светить их в /nix/store: сам
    # ~/.ssh/config — симлинк туда, читаемый на машине кем угодно.
    includes = [ osConfig.sops.secrets."ssh/config".path ];

    settings."*" = {
      # Приватный ключ в репозитории лежит зашифрованным (secrets/secrets.yaml),
      # на диск попадает только в /run/secrets. Путь берём у NixOS-модуля,
      # чтобы он не разъехался с именем секрета в features/secrets.nix.
      IdentityFile = osConfig.sops.secrets."ssh/${osConfig.my.username}_ed25519".path;
    };
  };
}
