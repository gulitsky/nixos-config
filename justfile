host := "laptop"

# Пересобрать и переключиться
switch:
    nh os switch . -H {{host}}

# Собрать без переключения
build:
    nh os build . -H {{host}}

# Проверить, что флейк вычисляется
check:
    nix flake check

fmt:
    nix fmt

update:
    nix flake update

# Что изменится по сравнению с текущей системой
diff:
    nvd diff /run/current-system result

# Собрать установочный ISO с вшитым конфигом
iso:
    nix build .#installer-iso -o result-iso
    @ls -lh result-iso/iso/

# Установка на чистую машину (с другого хоста, по ssh)
install target:
    nix run github:nix-community/nixos-anywhere -- \
      --flake .#{{host}} --generate-hardware-config nixos-facter hosts/{{host}}/facter.json \
      root@{{target}}
