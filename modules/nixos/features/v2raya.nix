{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.v2raya;

  # geoip.dat/geosite.dat одним каталогом. Без него v2rayA на старте решает,
  # что баз нет, и лезет за ними на github.com — то есть ровно туда, куда без
  # работающего узла и не попасть. Ищет он их в <XDG_DATA_DIRS>/<имя ядра>/,
  # а обёртка пакета v2raya кладёт свои базы в подкаталог v2ray/: с ядром
  # xray путь не совпадает и поиск промахивается. Поэтому каталог передаётся
  # явно — эта переменная перекрывает и XRAY_LOCATION_ASSET, и поиск по XDG.
  assets = pkgs.symlinkJoin {
    name = "xray-assets";
    paths = [
      pkgs.v2ray-geoip
      pkgs.v2ray-domain-list-community
    ];
  };
in
{
  options.my.v2raya = {
    enable = lib.mkEnableOption "v2rayA: веб-морда к xray-core на http://127.0.0.1:2017";

    logLevel = lib.mkOption {
      type = lib.types.enum [
        "trace"
        "debug"
        "info"
        "warn"
        "error"
      ];
      default = "info";
      description = ''
        Подробность лога. Пишется он не в journal, а в
        /var/log/v2raya/v2raya.log (так задано модулем nixpkgs), и /var/log —
        отдельный btrfs-сабволюм, так что лог переживает ребут.
        На "debug" видно, какой конфиг v2rayA генерирует ядру и что ядро
        отвечает при старте: первое, что стоит смотреть, когда узел
        подключён, но трафик не идёт.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.v2raya = {
      enable = true;

      # Ядро — xray, а не дефолтный для модуля v2ray (v2fly). Это не вопрос
      # вкуса: REALITY и flow=xtls-rprx-vision — расширения проекта XTLS,
      # в v2ray-core их нет вообще (`grep -c REALITY` по бинарнику: 0 против
      # 51 у xray). Ссылка vless:// с security=reality на v2ray-core
      # разбирается, узел появляется в списке и даже «пингуется», но
      # рукопожатие с сервером не складывается — и получается ровно то
      # поведение, когда прямые сайты открываются, а проксируемые висят.
      cliPackage = pkgs.xray;
    };

    systemd.services.v2raya.environment = {
      # Каждому флагу v2rayA соответствует переменная V2RAYA_<ФЛАГ>; модуль
      # nixpkgs своего ExecStart переопределить не даёт, так что настраиваем
      # через окружение.

      # По умолчанию v2rayA слушает 0.0.0.0:2017. Морда нужна только с этой
      # машины, поэтому прибиваем её к loopback — и тогда не нужно открывать
      # 2017 в firewall (в цепочке nixos-fw трафик с lo разрешён всегда).
      V2RAYA_ADDRESS = "127.0.0.1:2017";
      V2RAYA_V2RAY_ASSETSDIR = "${assets}/share/v2ray";
      V2RAYA_LOG_LEVEL = cfg.logLevel;
    };

    # Прозрачный проксик в режиме TPROXY принимает пакеты с чужими адресами
    # назначения на локальном сокете; строгий rp_filter (дефолт NixOS) их
    # отбрасывает. В режиме redirect не нужно, но переключается это в GUI,
    # а не в конфиге, — держим loose, чтобы переключение не ломало сеть.
    networking.firewall.checkReversePath = "loose";
  };
}
