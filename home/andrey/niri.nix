{
  config,
  pkgs,
  lib,
  ...
}:
let
  wpctl = lib.getExe' pkgs.wireplumber "wpctl";
  niri = lib.getExe pkgs.niri;
  systemctl = lib.getExe' pkgs.systemd "systemctl";

  # Раскладки перечислены один раз: отсюда собирается и xkb-строка для niri,
  # и подписи индикатора в waybar. Иначе третья раскладка добавляется в двух
  # местах, и рано или поздно они разъезжаются.
  layouts = [
    "us"
    "ru"
  ];

  # Модуля раскладки для niri в waybar нет: sway/language и hyprland/language
  # ходят в IPC своих композиторов. Зато у niri есть свой: event-stream при
  # подключении отдаёт KeyboardLayoutsChanged со всем списком и текущим
  # индексом, а дальше на каждое переключение — KeyboardLayoutSwitched с одним
  # индексом. Один процесс jq держит состояние в аккумуляторе foreach и печатает
  # строку только на этих двух событиях (остальных в потоке — десятки в секунду
  # при возне окнами), так что опроса по таймеру нет вообще.
  layoutIndicator = pkgs.writeShellScript "niri-layout-indicator" ''
    ${niri} msg -j event-stream | ${lib.getExe pkgs.jq} -n -c --unbuffered \
      --argjson labels '${builtins.toJSON (map lib.toUpper layouts)}' '
        foreach inputs as $e ({ idx: 0, names: [], show: false };
          if $e.KeyboardLayoutsChanged then
            $e.KeyboardLayoutsChanged.keyboard_layouts
            | { idx: .current_idx, names: .names, show: true }
          elif $e.KeyboardLayoutSwitched then
            .idx = $e.KeyboardLayoutSwitched.idx | .show = true
          else
            .show = false
          end;
          select(.show) | { text: ($labels[.idx] // "??"), tooltip: (.names[.idx] // "") }
        )'
  '';
in
{
  # niri не имеет модуля в nixpkgs/home-manager для типизированного конфига —
  # пишем KDL напрямую. Альтернатива: input niri-flake (sodiboo), он даёт
  # programs.niri.settings с проверкой типов. Начни с этого, мигрируй потом.
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "${lib.concatStringsSep "," layouts}"
                // CapsLock переключает раскладку (Shift+CapsLock — сам CapsLock).
                // ctrl:nocaps убран: одна клавиша не может быть и Ctrl,
                // и переключателем групп.
                options "grp:caps_toggle"
            }
            repeat-delay 300
            repeat-rate 50
        }

        touchpad {
            tap
            natural-scroll
            dwt                 // отключать тачпад во время набора
            accel-profile "adaptive"
            scroll-method "two-finger"
        }

        // TrackPoint T14: средняя кнопка + движение = скролл
        trackpoint {
            accel-speed 0.2
            scroll-method "on-button-down"
            scroll-button 274
            middle-emulation
        }

        // Не переносить фокус за курсором — на ноуте это раздражает.
        focus-follows-mouse max-scroll-amount="0%"
        warp-mouse-to-focus
    }

    output "eDP-1" {
        position x=0 y=0
        scale 1.0
        // T14 Gen1 FHD-панель. Для 2K-варианта поставь scale 1.25-1.5.
        // mode "1920x1080@60.000"
    }

    // Домашний Xiaomi Mi 34": стоит слева от ноутбука и выше него.
    // Нижние края выровнены (1080 - 1440 = -360) — курсор переходит между
    // экранами на всей высоте панели ноутбука, без мёртвых зон по вертикали.
    // 100 Гц вместо preferred 60: проверено на текущем HDMI-кабеле.
    output "HDMI-A-1" {
        mode "3440x1440@100.000"
        scale 1.0
        position x=-3440 y=-360
    }

    layout {
        gaps 8
        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        default-column-width { proportion 0.5; }

        focus-ring {
            width 2
            active-color "#89b4fa"
            inactive-color "#45475a"
        }

        border {
            off
        }

        struts {
            left 0
            right 0
        }
    }

    // xwayland-satellite: X11-приложения (Zoom, старые Electron, игры).
    // DISPLAY должен совпадать с тем, что satellite занимает.
    environment {
        DISPLAY ":0"
        NIXOS_OZONE_WL "1"
    }

    spawn-at-startup "${lib.getExe pkgs.xwayland-satellite}"
    spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"

    prefer-no-csd
    screenshot-path "~/Pictures/Screenshots/%Y-%m-%d %H-%M-%S.png"

    hotkey-overlay {
        skip-at-startup
    }

    window-rule {
        // Окна из foot-сервера приходят с app-id "footclient" (у самого foot —
        // "foot"). Матчилки в niri — нестрогие регекспы, но перечислены обе
        // явно: server-режим и запуск foot напрямую, если сервер лежит.
        match app-id="^footclient$"
        match app-id="^foot$"
        default-column-width { proportion 0.5; }
    }

    window-rule {
        geometry-corner-radius 8
        clip-to-geometry true
    }

    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }

        Mod+Return  { spawn "${lib.getExe' pkgs.foot "footclient"}"; }
        Mod+D       { spawn "${lib.getExe pkgs.walker}"; }
        Mod+B       { spawn "${lib.getExe pkgs.helium}"; }
        Mod+L       { spawn "${lib.getExe pkgs.swaylock}" "-f"; }
        Mod+Q       { close-window; }

        Mod+Left    { focus-column-left; }
        Mod+Down    { focus-window-down; }
        Mod+Up      { focus-window-up; }
        Mod+Right   { focus-column-right; }
        Mod+H       { focus-column-left; }
        Mod+J       { focus-window-down; }
        Mod+K       { focus-window-up; }
        Mod+Semicolon { focus-column-right; }

        Mod+Ctrl+H  { move-column-left; }
        Mod+Ctrl+J  { move-window-down; }
        Mod+Ctrl+K  { move-window-up; }
        Mod+Ctrl+Semicolon { move-column-right; }

        Mod+Home    { focus-column-first; }
        Mod+End     { focus-column-last; }

        Mod+U       { focus-workspace-down; }
        Mod+I       { focus-workspace-up; }
        Mod+Ctrl+U  { move-column-to-workspace-down; }
        Mod+Ctrl+I  { move-column-to-workspace-up; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }

        Mod+R       { switch-preset-column-width; }
        Mod+F       { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+C       { center-column; }
        Mod+Minus   { set-column-width "-10%"; }
        Mod+Equal   { set-column-width "+10%"; }
        Mod+V       { toggle-window-floating; }
        Mod+W       { toggle-column-tabbed-display; }

        Print       { screenshot; }
        Ctrl+Print  { screenshot-screen; }
        Alt+Print   { screenshot-window; }

        // Аппаратные клавиши T14. allow-when-locked нужен, иначе
        // с залоченного экрана не убавить звук.
        // wpctl (WirePlumber) вместо pamixer: тот ходил через libpulse и
        // pipewire-pulse. `-l 1.0` обязателен — без него wpctl уводит
        // громкость выше 100% и звук клиппит; pamixer упирался в 100 сам.
        XF86AudioRaiseVolume allow-when-locked=true { spawn "${wpctl}" "set-volume" "-l" "1.0" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "${wpctl}" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute        allow-when-locked=true { spawn "${wpctl}" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioMicMute     allow-when-locked=true { spawn "${wpctl}" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
        XF86MonBrightnessUp   allow-when-locked=true { spawn "${lib.getExe pkgs.brightnessctl}" "set" "5%+"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "${lib.getExe pkgs.brightnessctl}" "set" "5%-"; }

        Mod+Shift+E { quit; }
        Ctrl+Alt+Delete { quit; }
    }
  '';

  # environment {} выше задаёт переменные детям niri, но foot-сервер — это
  # user-юнит: он наследует окружение systemd-сессии, а туда niri импортирует
  # только WAYLAND_DISPLAY, DISPLAY, XDG_CURRENT_DESKTOP и NIRI_SOCKET.
  # Без этой строчки приложения, запущенные из терминала, теряли бы
  # NIXOS_OZONE_WL и Electron/Chromium уходили бы в XWayland.
  # environment.d читается менеджером при логине — применится со следующего
  # входа в сессию, не по `nh os switch`.
  systemd.user.sessionVariables.NIXOS_OZONE_WL = "1";

  # Walker 2.x — это только GTK4-фронтенд. Данные (список приложений, $PATH,
  # калькулятор, окна niri) отдаёт отдельный демон elephant по unix-сокету,
  # без него walker показывает «Waiting for elephant...».
  services.elephant = {
    enable = true;

    # По умолчанию пакет собирает все провайдеры разом и тянет в замыкание
    # bluez, imagemagick, wl-clipboard. Оставляем только нужные.
    #
    # clipboard выключен намеренно: историю буфера уже ведёт cliphist, два
    # вотчера на wl-paste дублировали бы друг друга. symbols (emoji, префикс
    # ".") выключен из-за размера: вшитая база превращает .so в 150 МиБ —
    # треть замыкания ради подборщика эмодзи.
    package = pkgs.elephant.override {
      enabledProviders = [
        "desktopapplications" # то, что раньше делал fuzzel
        "runner" # бинарники из $PATH, префикс ">"
        "files" # префикс "/", тянет fd
        "calc" # префикс "=", тянет qalc
        "websearch" # префикс "@", открывает через xdg-open
        "windows" # окна niri (`niri msg -j windows`), префикс "$"
        "menus" # на нём держатся fallback-действия walker'а
        "providerlist" # префикс ";" — список того, что вообще доступно
      ];
    };
  };

  # services.elephant.settings в home-manager кладёт config.toml, а elephant
  # 2.x читает elephant.toml (и <provider>.toml рядом с ним) — пишем сами.
  xdg.configFile."elephant/elephant.toml".text = ''
    # Иначе elephant находит в PATH "foot" и на каждый .desktop с
    # Terminal=true поднимает отдельный процесс foot мимо сервера.
    # Значение подставляется префиксом: "footclient <команда>".
    terminal_cmd = "${lib.getExe' pkgs.foot "footclient"}"
  '';

  # Провайдер menus читает ~/.config/elephant/menus/*.toml. Пункты питания
  # оформлены меню, а не .desktop-файлами: .desktop висел бы в списке
  # приложений всегда и во всех лаунчерах, а меню видно только по запросу.
  xdg.configFile."elephant/menus/power.toml".text = ''
    name = "power"
    name_pretty = "Питание"
    icon = "system-shutdown-symbolic"
    # Искать ещё и по имени меню — чтобы оба пункта находились по "power"
    # и "питание", а не только по собственному тексту.
    search_name = true

    # Команды перечислены таблицами actions, а не одним value + action
    # на меню: у «Перезагрузить» их две, и walker должен видеть обе, чтобы
    # развесить по разным клавишам (см. providers.actions ниже).
    #
    # Пароля ничего из этого не спросит: в политике polkit у logind
    # и poweroff/reboot, и set-reboot-to-firmware-setup идут с
    # allow_active = yes, а elephant крутится в активной локальной сессии.
    [[entries]]
    text = "Выключить"
    icon = "system-shutdown-symbolic"
    keywords = [ "poweroff", "shutdown", "выключить", "выключение" ]

    [entries.actions]
    run = "${systemctl} poweroff"

    [[entries]]
    text = "Перезагрузить"
    icon = "system-reboot-symbolic"
    keywords = [ "reboot", "restart", "перезагрузка", "ребут", "uefi", "bios" ]

    [entries.actions]
    run = "${systemctl} reboot"
    # Просит firmware поднять при следующем старте setup-интерфейс (флаг
    # OsIndications в EFI). `bootctl status` на этом ноуте подтверждает
    # поддержку: "Boot into FW: supported".
    firmware = "${systemctl} reboot --firmware-setup"
  '';

  services.walker = {
    enable = true;

    # menus в дефолтном наборе — иначе меню питания достижимо только через
    # префикс. Список задаётся целиком: walker подменяет providers.default
    # своим значением, а не дополняет вшитый (в отличие от providers.prefixes,
    # которые он мержит по имени провайдера).
    settings.providers = {
      default = [
        "desktopapplications"
        "calc"
        "websearch"
        "menus"
      ];

      # Клавиши для действий меню питания. Ключ — полное имя провайдера
      # вместе с именем меню: ровно то, что elephant кладёт в item.provider
      # и по чему walker ищет привязки. Вшитый набор он мержит по имени
      # действия, так что fallback-действия (back, clear hist) остаются.
      actions."menus:power" = [
        {
          action = "run";
          bind = "Return";
          # Обязательно, а не для красоты: пункт, у которого действий больше
          # одного, walker активирует мышью только через default = true —
          # без него activate_default() падает на unwrap().
          default = true;
        }
        {
          action = "firmware";
          bind = "ctrl Return";
          label = "в UEFI";
        }
      ];
    };

    # Холодный старт GTK4 заметен глазом, поэтому walker живёт демоном, а
    # Mod+D запускает клиент, который будит уже поднятый процесс. Тот же
    # приём, что с foot --server / footclient.
    systemd.enable = true;

    # Тема подменяет только style.css; layout.xml, keybind.xml и item_*.xml
    # walker берёт из вшитых дефолтов — переопределять их не нужно.
    theme = {
      name = "cameo";
      style = ''
        @define-color window_bg_color #1e1e2e;
        @define-color accent_bg_color #45475a;
        @define-color theme_fg_color #cdd6f4;
        @define-color border_color #89b4fa;
        @define-color error_bg_color #f38ba8;
        @define-color error_fg_color #1e1e2e;

        /* Дефолтная тема walker'а начинается с полного сброса — без него
           поверх лезет Adwaita. Раз сброшено всё, шрифт задаём тут же. */
        * {
          all: unset;
          font-family: "Inter", "Cascadia Mono NF";
          font-size: 12px;
        }

        scrollbar {
          opacity: 0;
        }

        popover {
          background: @window_bg_color;
          border: 1px solid @accent_bg_color;
          border-radius: 8px;
          padding: 10px;
        }

        .normal-icons {
          -gtk-icon-size: 16px;
        }

        .large-icons {
          -gtk-icon-size: 32px;
        }

        .box-wrapper {
          background: alpha(@window_bg_color, 0.87);
          border: 1px solid @border_color;
          border-radius: 8px;
          padding: 16px;
          box-shadow:
            0 19px 38px rgba(0, 0, 0, 0.3),
            0 15px 12px rgba(0, 0, 0, 0.22);
        }

        .input {
          caret-color: @theme_fg_color;
          background: alpha(@accent_bg_color, 0.5);
          color: @theme_fg_color;
          border-radius: 8px;
          padding: 10px;
        }

        .input placeholder {
          opacity: 0.5;
        }

        .input selection {
          background: @accent_bg_color;
        }

        .list,
        .placeholder,
        .elephant-hint,
        .preview-box {
          color: @theme_fg_color;
        }

        .item-box {
          border-radius: 8px;
          padding: 8px 10px;
        }

        child:selected .item-box,
        row:selected .item-box {
          background: @accent_bg_color;
        }

        .item-quick-activation {
          background: alpha(@accent_bg_color, 0.5);
          border-radius: 4px;
          padding: 8px;
        }

        .item-subtext {
          font-size: 11px;
          opacity: 0.5;
        }

        .providerlist .item-subtext {
          font-size: unset;
          opacity: 0.75;
        }

        .item-image-text {
          font-size: 28px;
        }

        .calc .item-text {
          font-size: 24px;
        }

        .symbols .item-image {
          font-size: 24px;
        }

        .preview {
          border: 1px solid @accent_bg_color;
          border-radius: 8px;
          color: @theme_fg_color;
        }

        .preview .large-icons {
          -gtk-icon-size: 64px;
        }

        .keybinds {
          padding-top: 10px;
          border-top: 1px solid @accent_bg_color;
          font-size: 11px;
          color: @theme_fg_color;
        }

        .keybind-button {
          opacity: 0.5;
        }

        .keybind-button:hover {
          opacity: 0.75;
        }

        .keybind-bind {
          text-transform: lowercase;
          opacity: 0.35;
        }

        .keybind-label {
          padding: 2px 4px;
          border-radius: 4px;
          border: 1px solid @theme_fg_color;
        }

        .error {
          background: @error_bg_color;
          color: @error_fg_color;
          border-radius: 8px;
          padding: 10px;
        }

        :not(.calc).current {
          font-style: italic;
        }
      '';
    };
  };

  services.mako = {
    enable = true;
    settings = {
      font = "Inter 11";
      background-color = "#1e1e2ee6";
      text-color = "#cdd6f4";
      border-color = "#89b4fa";
      border-radius = 8;
      default-timeout = 5000;
    };
  };

  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "${lib.getExe pkgs.swaylock} -f";
      }
      {
        timeout = 360;
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
      }
    ];
    events.before-sleep = "${lib.getExe pkgs.swaylock} -f";
  };

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.mainBar = {
      layer = "top";
      position = "left";
      width = 44;
      modules-left = [ "niri/workspaces" ];
      modules-right = [
        "custom/layout"
        # Нативный модуль WirePlumber вместо "pulseaudio": тот ходит через
        # libpulse и pipewire-pulse. Прослойка рабочая (и services.pipewire.pulse
        # выключать нельзя — через него ходят браузеры и Electron), просто
        # панели она не нужна. Взамен теряются иконки по типу порта
        # (наушники/HDMI) — их тут всё равно не было.
        "wireplumber"
        "battery"
        "clock"
        "tray"
      ];

      "custom/layout" = {
        exec = layoutIndicator;
        return-type = "json";
        justify = "center";
        # Скрипт умирает вместе с event-stream, когда niri перезапускается.
        # Без restart-interval waybar его больше не поднимет, и индикатор
        # молча замрёт на последней раскладке.
        restart-interval = 1;
        on-click = "${niri} msg action switch-layout next";
      };

      battery = {
        format = "{icon}\n{capacity}";
        # Иначе строки многострочной метки прижимаются влево.
        justify = "center";
        format-icons = [
          "󰁺"
          "󰁽"
          "󰂀"
          "󰂃"
          "󰁹"
        ];
        states = {
          warning = 25;
          critical = 10;
        };
      };

      wireplumber = {
        format = "{icon}\n{volume}";
        justify = "center";
        format-muted = "󰝟";
        # У wireplumber-модуля это плоский список, а не attrs с .default.
        format-icons = [
          "󰕿"
          "󰖀"
          "󰕾"
        ];
        on-click = "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };

      clock = {
        locale = "ru_RU.UTF-8";
        format = "{:%H\n%M}";
        justify = "center";
        # Без флага L fmt форматирует по locale "C" — день недели был английским.
        tooltip-format = "<big>{:L%a %d.%m.%Y}</big>\n<tt>{calendar}</tt>";
      };

      tray = {
        icon-size = 16;
        spacing = 6;
      };
    };

    style = ''
      * {
        font-family: "Inter", "Cascadia Mono NF";
        font-size: 12px;
      }
      window#waybar {
        background: rgba(30, 30, 46, 0.85);
        color: #cdd6f4;
      }
      #workspaces { margin-top: 6px; }
      #workspaces button { padding: 4px 0; margin: 2px 4px; }
      #workspaces button.focused { background: #45475a; }
      #battery.critical { color: #f38ba8; }
      #clock, #battery, #wireplumber, #tray, #custom-layout { padding: 8px 0; }
    '';
  };

  # Оба модуля из nixpkgs собирают юниты без триггеров перезапуска, поэтому
  # после правки темы или elephant.toml сервисы продолжали бы крутиться со
  # старым конфигом (та же грабля, что с `foot --server`). Вешаем на юниты
  # пути сгенерированных файлов: меняется путь — systemd перезапускает сервис
  # на `nh os switch` сам.
  #
  # ConditionEnvironment здесь безопасен: niri импортирует WAYLAND_DISPLAY в
  # сессию до graphical-session.target, на этом же условии живёт foot.service
  # (подробности — в terminal.nix).
  systemd.user.services = {
    elephant.Unit = {
      ConditionEnvironment = "WAYLAND_DISPLAY";
      X-Restart-Triggers = [
        "${config.xdg.configFile."elephant/elephant.toml".source}"
        "${config.xdg.configFile."elephant/menus/power.toml".source}"
      ];
    };

    walker.Unit = {
      ConditionEnvironment = "WAYLAND_DISPLAY";
      X-Restart-Triggers = [
        "${config.xdg.configFile."walker/config.toml".source}"
        "${config.xdg.configFile."walker/themes/cameo/style.css".source}"
      ];
    };
  };

  services.cliphist.enable = true;
}
