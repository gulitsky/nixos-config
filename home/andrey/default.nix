{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./niri.nix
    ./shell.nix
    ./ssh.nix
    ./terminal.nix
  ];

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    helium # из флейка inputs.helium (в nixpkgs его нет)
    # claude-code даёт programs.claude-code ниже — вторая запись здесь лишняя
    inputs.fresh.packages.${pkgs.stdenv.hostPlatform.system}.default # Fresh IDE: терминальный редактор
    # LSP для .nix. Fresh поднимает его сам и зовёт именно `nil` (nixd у него
    # значится альтернативой, команду пришлось бы прописывать руками), поэтому
    # пакет нужен в PATH сессии: из devShell он виден только в `nix develop`.
    nil
    ripgrep
    fd
    jq
    htop
    python3 # для разовых скриптов; проектные зависимости — через devShell
    just
    glab
    bluetui # TUI для bluetooth: пары, подключение, батарея устройств
    imv
    mpv
    # Форк Telegram Desktop (ghost mode, больше настроек). Данные лежат в
    # ~/.local/share — он уже в списке persist, переживает reboot.
    ayugram-desktop

    # Управление системой и секретами с самого ноута: иначе шаг 4 README
    # (sops/age) и `nh os switch` работают только внутри `nix develop`.
    nh
    sops
    age # даёт age-keygen
    ssh-to-age
  ];

  # Go по умолчанию кладёт GOPATH в ~/go, а этого пути нет в списке
  # impermanence — кэш модулей и `go install` стирались бы каждую загрузку.
  # ~/.local/share персистится, поэтому GOPATH переезжает туда.
  home.sessionVariables.GOPATH = "${config.home.homeDirectory}/.local/share/go";
  home.sessionPath = [ "${config.home.homeDirectory}/.local/share/go/bin" ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "Andrey Gulitsky";
      user.email = "angulitsky@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  # Claude Code модулем, а не пакетом в списке выше: модуль умеет объявлять
  # MCP-серверы. Кладёт он их не в ~/.claude.json (тот файл Claude Code ведёт
  # сам), а в синтезированный плагин `hm`, поэтому инструменты называются
  # mcp__plugin_hm_<сервер>__<инструмент>. Проектные серверы объявлять здесь
  # поэтому нельзя: скиллы репозиториев зовут их по короткому имени.
  programs.claude-code = {
    enable = true;

    mcpServers.nixos = {
      # Справочник по пакетам nixpkgs и опциям NixOS прямо в сессии.
      # Абсолютный путь до uvx, а не короткое имя: uv стоит только в devShell'ах
      # проектов, а сессия открывается из любого каталога. Сам mcp-nixos uvx
      # тянет с PyPI в ~/.cache/uv — этот каталог персистится.
      command = lib.getExe' pkgs.uv "uvx";
      args = [ "mcp-nixos" ];
    };
  };

  # Браузер по умолчанию для xdg-open и ссылок из приложений.
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      let
        helium = [ "helium.desktop" ];
      in
      {
        "text/html" = helium;
        "x-scheme-handler/http" = helium;
        "x-scheme-handler/https" = helium;
        "x-scheme-handler/about" = helium;
        "x-scheme-handler/unknown" = helium;
        "application/pdf" = helium;
      };
  };

  # Тёмная тема по умолчанию. Главное здесь — color-scheme в dconf: его
  # читает xdg-desktop-portal-gnome и отдаёт приложениям через
  # org.freedesktop.appearance, поэтому GTK4/libadwaita, Electron и
  # Chromium (в том числе helium) темнеют без своих настроек. gtk3 и qt
  # ниже — для тех, кто портал не спрашивает.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    # Новый дефолт home-manager (со stateVersion 26.05) вместо унаследованного
    # gtk4.theme = config.gtk.theme. Он же и правильный: libadwaita темы
    # gtk-theme-name игнорирует, тёмный режим ей задаёт color-scheme выше,
    # а прописанная тема только сбивает часть GTK4-приложений.
    gtk4.theme = null;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Курсор: без этого в niri он невидим до первого движения над окном.
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
  };
}
