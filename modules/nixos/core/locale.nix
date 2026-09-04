{ pkgs, ... }:
{
  time.timeZone = "Asia/Omsk";

  i18n.defaultLocale = "ru_RU.UTF-8";

  console.keyMap = "ruwin_cplk-UTF-8";
  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-u32n.psf.gz";
}
