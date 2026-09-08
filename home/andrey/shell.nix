{ pkgs, ... }:
{
  programs.fish = {
    enable = true;

    shellAbbrs = {
      g = "git";
      gs = "git status";
      gd = "git diff";
      ll = "eza -l --git";
      la = "eza -la --git";
      nrs = "nh os switch ~/Projects/cameo/os";
      nrb = "nh os build ~/Projects/cameo/os";
    };

    functions.mkcd = {
      description = "создать каталог вместе с родителями и сразу войти в него";
      # Функцией, а не аббревиатурой: `cd` должен сработать в текущей оболочке,
      # а внешний скрипт менял бы каталог только своему процессу.
      body = ''
        if test (count $argv) -ne 1
          echo "mkcd: нужен ровно один путь" >&2
          return 1
        end

        # `and`, а не `;`: если mkdir упал (нет прав, файл с таким именем),
        # молча остаться в прежнем каталоге хуже, чем не двигаться вообще.
        mkdir -p -- $argv[1]; and cd -- $argv[1]
      '';
    };

    interactiveShellInit = ''
      set -g fish_greeting

      # fish не наследует переменные из nix-shell так, как bash;
      # direnv-хук обязателен, иначе devShell'ы «не видны».
      ${pkgs.direnv}/bin/direnv hook fish | source
    '';
  };

  programs.eza = {
    enable = true;
    icons = "auto";
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      nix_shell.format = "[$symbol$name]($style) ";
    };
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.bat.enable = true;
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  # Файловый менеджер. TUI под остальной набор (foot + fish + Fresh): открывается
  # в том же окне, ходит теми же fd/rg/fzf/zoxide, что уже стоят.
  #
  # extraPackages не нужен: пакет в nixpkgs уже завёрнут вместе с
  # превьюшниками — ffmpeg, poppler-utils, imagemagick, resvg, chafa, 7zz, file.
  # Картинки foot показывает честно, сикселями, а не ASCII-заглушкой chafa.
  programs.yazi = {
    enable = true;

    # Обёртка на fish: сам yazi сменить каталог родительской оболочке не может,
    # поэтому пишет итоговый cwd в файл, а функция делает по нему cd.
    enableFishIntegration = true;

    # Явно, хотя "y" — и есть новый дефолт: со stateVersion ниже 26.05
    # home-manager отдаёт унаследованное "yy" и вешает warning.
    shellWrapperName = "y";

    settings.mgr = {
      # В конфигах и дотфайлах скрытых файлов больше, чем видимых, — прятать их
      # в файловом менеджере этого репозитория бессмысленно.
      show_hidden = true;
      sort_dir_first = true;
    };
  };
}
