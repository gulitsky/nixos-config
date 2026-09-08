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

# Пакет virtio-win в nixpkgs распакованный, готового .iso в сторе нет — образ
# собирается из него, качать с fedorapeople вручную не нужно.
#
# ISO с virtio-драйверами для установщика Windows
virtio-iso out="$HOME/Downloads/virtio-win.iso":
    nix shell --inputs-from . nixpkgs#cdrkit -c genisoimage -J -r -V virtio-win \
      -o {{out}} $(nix build --inputs-from . --no-link --print-out-paths nixpkgs#virtio-win)
    @echo "готово: {{out}} — подключить вторым приводом при установке"

# Домен создаётся с secure-boot-прошивкой и TPM 2.0 (без них установщик
# Windows 11 отказывается идти), диск и сеть virtio, вторым приводом —
# драйверы, иначе установщик не увидит диск.
#
# Создать виртуалку Windows: `just win-create ~/Downloads/win11.iso`
win-create iso virtio="$HOME/Downloads/virtio-win.iso" name="win11" disk="100" ram="8192" vcpus="4":
    virt-install --connect qemu:///system \
      --name {{name}} --osinfo win11 \
      --vcpus {{vcpus}} --memory {{ram}} --cpu host-passthrough --machine q35 \
      --boot firmware=efi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=yes \
      --features smm.state=on \
      --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
      --disk size={{disk}},format=qcow2,bus=virtio,discard=unmap,boot.order=2 \
      --disk device=cdrom,path={{iso}},boot.order=1 \
      --disk device=cdrom,path={{virtio}},boot.order=3 \
      --network network=default,model=virtio \
      --graphics spice --video qxl \
      --noautoconsole

# Открыть консоль виртуалки
win name="win11":
    virt-manager --connect qemu:///system --show-domain-console {{name}}
