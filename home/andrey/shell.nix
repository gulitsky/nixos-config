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
}
