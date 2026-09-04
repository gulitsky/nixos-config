{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.profiles.niri;
in
{
  options.my.profiles.niri.enable = lib.mkEnableOption "Wayland-сессия на niri";

  config = lib.mkIf cfg.enable {
    # Модуль из nixpkgs: ставит niri, .desktop-сессию, systemd-таргеты
    # и переменные окружения сессии.
    programs.niri.enable = true;

    # Логин. tuigreet вместо GDM: не тянет за собой полгнома
    # и переживает impermanence без персиста.
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${lib.getExe pkgs.tuigreet} --time --remember --remember-session --cmd niri-session";
        user = "greeter";
      };
    };
    # Иначе логи greetd лезут поверх TUI.
    systemd.services.greetd.serviceConfig.Type = "idle";

    # Порталы. niri рекомендует gnome-портал для screencast (PipeWire)
    # и gtk — для file chooser.
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
      ];
      config.common.default = [
        "gnome"
        "gtk"
      ];
    };

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    security.rtkit.enable = true;

    security.polkit.enable = true;
    services.gnome.gnome-keyring.enable = true;

    # swaylock должен уметь проверять пароль.
    security.pam.services.swaylock = { };

    programs.dconf.enable = true;

    environment.systemPackages = with pkgs; [
      # niri сам ничего из этого не тянет — композитор и только.
      xwayland-satellite # X11-приложения внутри niri
      # Лаунчер (walker + бэкенд elephant) ставит home-manager: пакет elephant
      # там пересобран под урезанный набор провайдеров, и второй копии
      # с полным набором в PATH быть не должно.
      waybar # панель
      mako # уведомления
      swaylock
      swayidle
      wl-clipboard
      cliphist
      brightnessctl
      playerctl
      grim
      slurp
      xdg-utils
      polkit_gnome
    ];

    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        inter
        jetbrains-mono
        nerd-fonts.jetbrains-mono
        noto-fonts
        noto-fonts-color-emoji
      ];
      fontconfig.defaultFonts = {
        monospace = [ "JetBrains Mono" ];
        sansSerif = [ "Inter" ];
      };
    };
  };
}
