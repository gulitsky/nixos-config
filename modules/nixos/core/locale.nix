{ pkgs, ... }:
{
  time.timeZone = "Asia/Omsk";

  i18n.defaultLocale = "ru_RU.UTF-8";

  # Раскладка консоли остаётся us: пароль LUKS и логин набираются латиницей,
  # а переключаться в TTY нечем — grp:caps_toggle живёт только в niri.
  console.keyMap = "us";
  # Дефолтный шрифт консоли без кириллицы: с ru_RU сообщения systemd
  # превращались бы в ряд плашек. У terminus кириллица есть.
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
}
