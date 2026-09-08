# Список оверлеев для системы и devShell — импортируется из flake.nix и из
# modules/nixos/core/nix.nix, чтобы `nix build` и `nh os switch` собирали
# одни и те же пакеты.
inputs: [
  inputs.helium.overlays.default

  (_final: prev: {
    # Флейк отдаёт helium без наших флагов. --ozone-platform-hint он
    # подставляет сам по NIXOS_OZONE_WL, а декорации Chromium под Wayland
    # приходится включать явно.
    helium = prev.helium.override {
      flags = [ "--enable-features=WaylandWindowDecorations" ];
    };
  })

  (final: prev: {
    # niri-session зовёт `systemctl --user import-environment` без аргументов,
    # а systemd 258+ печатает на этот вызов предупреждение об устаревании —
    # оно и висит на tty при входе (niri-wm/niri#254). Перечисляем имена
    # переменных явно: импортируется ровно то же самое (всё окружение
    # целиком), но молча.
    # Патчим готовый скрипт через symlinkJoin, а не overrideAttrs, — иначе
    # niri пришлось бы пересобирать из исходников ради одной строки.
    niri =
      let
        base = prev.niri;
        # Тот же awk-трюк, что в ветке для dinit в самом niri-session.
        # AWKPATH/AWKLIBPATH добавляет сам gawk, в окружении их нет —
        # systemctl ругался бы на них «not set, ignoring».
        names = "${final.gawk}/bin/awk 'BEGIN { for (v in ENVIRON) if (v !~ /^AWK(PATH|LIBPATH)$/) print v }'";
      in
      (final.symlinkJoin {
        name = "niri-${base.version}";
        # Все выходы, иначе из системного профиля пропадёт офлайн-вики
        # из выхода doc.
        paths = map (o: base.${o}) base.outputs;
        postBuild = ''
          rm -r $out/bin
          mkdir -p $out/bin
          ln -s ${base}/bin/* $out/bin/
          rm $out/bin/niri-session
          substitute ${base}/bin/niri-session $out/bin/niri-session \
            --replace-fail 'systemctl --user import-environment' \
            "systemctl --user import-environment \$(${names})"
          chmod +x $out/bin/niri-session
        '';
      })
      // {
        # symlinkJoin теряет метаданные; providedSessions нужен модулю
        # services.displayManager.sessionPackages.
        inherit (base) version meta passthru;
        inherit (base.passthru) providedSessions;
      };
  })
]
