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
]
