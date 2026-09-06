_: {
  programs.foot = {
    enable = true;

    # Клиент-серверный режим. Один процесс `foot --server` держит разобранный
    # конфиг, загруженные шрифты и их glyph-кэш, окна открывает `footclient` —
    # новое окно появляется мгновенно и не платит за старт шрифтов заново.
    #
    # home-manager вешает юнит foot.service на graphical-session.target с
    # ConditionEnvironment=WAYLAND_DISPLAY. niri.service объявлен
    # Before=graphical-session.target и сам делает
    # `systemctl --user import-environment WAYLAND_DISPLAY DISPLAY
    # XDG_CURRENT_DESKTOP NIRI_SOCKET` — к старту таргета переменная уже есть,
    # условие выполняется.
    #
    # Цена режима, о ней стоит помнить:
    #   - падение сервера уносит все окна разом (в юните Restart=on-failure);
    #   - конфиг читается один раз при старте сервера, поэтому после правок
    #     этого файла нужен `systemctl --user restart foot`, иначе изменений
    #     не видно (SIGUSR1/SIGUSR2 у foot — переключение тёмной/светлой
    #     темы, а не reload);
    #   - дочерние процессы наследуют окружение systemd-сессии, а не того, кто
    #     позвал footclient. Из-за этого NIXOS_OZONE_WL объявлен в
    #     systemd.user.sessionVariables (см. niri.nix).
    server.enable = true;

    settings = {
      main = {
        term = "foot";
        font = "Cascadia Mono NF:size=11";
        dpi-aware = "no";
        pad = "8x8";
      };
      scrollback.lines = 10000;
      mouse.hide-when-typing = "yes";

      cursor.style = "beam";

      "colors-dark" = {
        alpha = 0.96;
        background = "1e1e2e";
        foreground = "cdd6f4";
        regular0 = "45475a";
        regular1 = "f38ba8";
        regular2 = "a6e3a1";
        regular3 = "f9e2af";
        regular4 = "89b4fa";
        regular5 = "f5c2e7";
        regular6 = "94e2d5";
        regular7 = "bac2de";
        bright0 = "585b70";
        bright1 = "f38ba8";
        bright2 = "a6e3a1";
        bright3 = "f9e2af";
        bright4 = "89b4fa";
        bright5 = "f5c2e7";
        bright6 = "94e2d5";
        bright7 = "a6adc8";
      };
    };
  };
}
