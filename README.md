# NixOS config

Хост: `laptop` — Ryzen 5 PRO 4650U (Renoir), AMD iGPU, btrfs + LUKS2, tmpfs root.

## Раскладка

    flake.nix              inputs + mkHost, больше ничего
    modules/nixos/
      core/                верно для любой машины, без флагов
      features/            опциональное поведение: my.<feature>.enable
      profiles/            наборы: my.profiles.<name>.enable
    hosts/laptop/          ТОЛЬКО факты про железо + какие флаги включить
    home/andrey/           home-manager
    secrets/               sops

Правило: логика живёт в `modules/`, хост — это список булевых флагов.

## Порядок ввода в строй

Не включай всё сразу — каждый шаг отдельно проверяется загрузкой.

**1. Проверить, что вычисляется** (можно прямо тут, из WSL):

    nix flake check
    nix build .#nixosConfigurations.laptop.config.system.build.toplevel

**2. Диски.** Подставь реальный `device` в `hosts/laptop/disko.nix`,
загрузись с NixOS ISO и:

    sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
      --mode disko --flake .#laptop
    sudo nixos-install --flake .#laptop --no-root-passwd

На этом шаге `my.impermanence.enable` уже true — root эфемерный с самого начала,
чтобы не привыкать к состоянию, которое потом исчезнет.

**3. Первая загрузка.** Пароль пользователя ещё не работает (секрет пустой) —
временно закомментируй `hashedPasswordFile` и поставь
`initialHashedPassword = "..."` (`mkpasswd -m sha-512`).

**4. sops.** Ключи уже сгенерированы и вписаны в `.sops.yaml`: личный лежит в
`~/.config/sops/age/keys.txt` (переживает reboot — `.config` в списке persist),
хостовый выведен из `/persist/etc/ssh/ssh_host_ed25519_key`. Повторить при
необходимости:

    ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub    # -> age1... хоста
    age-keygen -y ~/.config/sops/age/keys.txt          # публичная часть твоего

Дальше — пароль:

    mkpasswd -m sha-512
    sops secrets/secrets.yaml
    # users:
    #   andrey: "$6$..."

Личный ssh-ключ живёт там же. Приватная часть — секретом sops, публичная —
в `users.users.andrey.openssh.authorizedKeys.keys` (закомментирована):

    sops set secrets/secrets.yaml '["ssh"]["andrey_ed25519"]' \
      "$(jq -Rs . < ~/.ssh/id_ed25519)"

Вторым секретом — список хостов, готовый кусок `ssh_config`: адреса, порты и
логины в публичном репозитории не нужны.

    sops set secrets/secrets.yaml '["ssh"]["config"]' \
      "$(jq -Rs . < <старый ~/.ssh/config>)"

Оба объявлены в `modules/nixos/features/secrets.nix` и приезжают в
`/run/secrets/ssh/` (в `~/.ssh` их класть нельзя: там bind-mount
impermanence). `home/andrey/ssh.nix` даёт ключ через `IdentityFile`, а хосты
подключает через `Include` — в самом репозитории от них не остаётся ничего.
Секреты обязаны существовать до `switch`: `sops-install-secrets` падает в
activation, если объявленного ключа в `secrets.yaml` нет.

Затем три правки за один switch: `my.secrets.enable = true` в
`hosts/laptop/default.nix`, возврат `hashedPasswordFile` вместо
`initialHashedPassword` в `modules/nixos/core/users.nix`,
`sudo nixos-rebuild switch --flake .#laptop`. Перезагрузиться, проверить логин.

`my.secrets.enable` включается **только вместе** с настоящим зашифрованным
`secrets.yaml`: sops-install-secrets падает в activation, если файл — заглушка.

`sops`, `age`, `ssh-to-age`, `nh` перечислены в `home/andrey/default.nix`, но
до первого `switch` их в PATH нет — тогда `nix develop` или
`nix shell --inputs-from . nixpkgs#sops`.

**5. Impermanence.** Загрузись, поработай день, перезагрузись. Всё, что
«забылось» и должно было остаться — дописывай в
`modules/nixos/features/impermanence.nix`. Типичные пропажи: пары Bluetooth,
Wi-Fi-профили, `~/.local/state`, токены приложений, лицензии.

**6. Secure Boot.** Порядок именно такой: ключи → подписанные UKI на ESP →
только потом Setup Mode и включение SB в прошивке. Наоборот — получишь
машину, которая не грузится, и придётся выключать SB из BIOS.

Ключи (sbctl кладёт их в `/var/lib/sbctl/keys`, приватный — только для root).
Сам `sbctl` в системе появляется после любого `nh os switch` — он в
`environment.systemPackages` независимо от флага, именно ради этого шага:

    sudo sbctl create-keys
    sudo sbctl status

Затем `my.secureboot.enable = true` в `hosts/laptop/default.nix` и
`nh os switch`. lanzaboote заменяет собой systemd-boot: собирает на каждую
генерацию цельный UKI и подписывает его ключом db. Проверить **до**
перезагрузки:

    sudo sbctl verify

Ожидаемо: подписаны `BOOTX64.EFI`, `systemd-bootx64.efi` и все
`EFI/Linux/nixos-generation-*.efi`. А `EFI/nixos/kernel-*.efi` не подписан, и
так и должно быть: подпись стоит только на stub, а ядро и initrd stub проверяет
по хешам, вшитым в него самого. Подписывать их отдельно нечего.

Только теперь — прошивка. Перезагрузиться в BIOS (F1 или пункт «Reboot into
Firmware» в меню загрузчика), дальше Security → Secure Boot:

1. Secure Boot → Enabled
2. **Reset to Setup Mode**
3. F10 (save & exit)

«Clear All Secure Boot Keys» — **не** трогать: она заодно выносит dbx (список
отозванных загрузчиков), и его потом ничем не вернуть, кроме
«Restore Factory Keys» с последующим повтором всей процедуры.

Загрузиться в NixOS (в Setup Mode прошивка грузит что угодно) и вписать свои
ключи в NVRAM:

    # Ядро помечает переменные в efivarfs immutable, иначе enroll-keys упрётся
    # в «File is immutable». Флаг возвращается при каждой загрузке — это норма.
    cd /sys/firmware/efi/efivars
    sudo chattr -i KEK-8be4df61-93ca-11d2-aa0d-00e098032b8c                    db-d719b2cb-3d3a-4596-a3bc-dad00e67656f

    sudo sbctl enroll-keys --microsoft   # --microsoft обязателен: без ключей MS
                                         # option ROM видеокарты/сетевой может не стартовать
    sudo reboot

PK в списке нет специально: в Setup Mode прошивка его удалила, а новую
переменную sbctl создаёт без препятствий.

Проверка: `bootctl status` → `Secure Boot: enabled (user)`. И заодно, что dbx
не опустел: `ls -l /sys/firmware/efi/efivars/dbx-*` — там должны быть
десятки килобайт, а не пара сотен байт.

`/var/lib/sbctl` уже в списке persist — иначе ключи пропадут после reboot.

Место на ESP lanzaboote почти не ест: ядро и initrd лежат в `EFI/nixos`
content-addressed, как и при systemd-boot, поэтому генерации с одним ядром
делят одни файлы, а на генерацию приходится только stub с cmdline и хешами.
1 ГБ раздела и `configurationLimit = 10` — это ~80 МБ. Лимит падает до 8
только при `measuredBoot` (шаг 8): systemd-pcrlock не строит политику на
большее число вариантов.

**Если не грузится:** выключить Secure Boot в BIOS — система поднимется, UKI
и так лежат на ESP. Разбираться дальше через `sudo sbctl verify` и
`bootctl status`.

**7. TPM2-unlock.** Только после того, как Secure Boot стабильно работает:
токен привязывается к PCR 7, а он и есть состояние Secure Boot.

    # СНАЧАЛА recovery-ключ — иначе один сбой TPM и диск не открыть
    sudo systemd-cryptenroll /dev/nvme0n1p2 --recovery-key

    sudo systemd-cryptenroll /dev/nvme0n1p2 \
      --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes

    sudo cryptsetup luksDump /dev/nvme0n1p2 | grep -A2 Tokens

**Выбор: PIN или полный автоанлок.** С `--tpm2-with-pin=yes` PIN спрашивают
каждую загрузку. Без флага диск открывается сам — вводить нечего.

Автоанлок закрывает: вынутый из ноута диск и загрузку с выключенным Secure
Boot или чужими ключами (PCR 7 меняется, TPM отказывает). Не закрывает
главное — кражу самого ноута: PCR 7 совпадает, TPM отдаёт ключ, диск
расшифрован, и вся защита сводится к паролю логина и к тому, что доступно до
него. А `/persist` уже смонтирован, и в нём age-ключ sops, то есть все секреты.

PIN — не вторая парольная фраза LUKS. Фраза LUKS обязана выдерживать офлайн-
перебор, поэтому длинная; PIN проверяет сам чип, у него anti-hammering, поэтому
6 цифр осмысленны. Обмен именно такой: короткий PIN вместо длинной фразы.

Выбрано: PIN. Передумать — одна команда:

    sudo systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=tpm2       --tpm2-device=auto --tpm2-pcrs=7        # без PIN, автоанлок

Recovery-ключ распечатать/положить вне этого диска. Инвалидируют enroll:
перевыпуск ключей sbctl, `enroll-keys` заново, обновление прошивки,
включение/выключение Secure Boot, `sbctl reset`. Пароль LUKS при этом
остаётся рабочим всегда — TPM только добавляет слот, не заменяет.

**Слоты LUKS после шага 7** (`cryptsetup luksDump /dev/nvme0n1p2`):

| слот | KDF | токен | чем открывается |
|---|---|---|---|
| 0 | argon2id | — | парольная фраза, в голове |
| 1 | pbkdf2 | `systemd-recovery` | recovery-ключ, на бумаге |
| 3 | pbkdf2 | `systemd-tpm2` | TPM2 + PIN, только на этой машине |

Слот 0 не удалять, хотя `--wipe-slot=password` это умеет. PIN — не запасной
вход: он работает только с этим чипом и совпавшим PCR 7. А TPM-путь отваливается
как раз от обновления прошивки, повторного `enroll-keys`, очистки чипа или замены
платы — то есть тогда, когда бумажки с recovery может не быть под рукой. Плюс
rescue-ISO: там TPM-токена нет вообще, только фраза. Если фраза слабая — менять
(`cryptsetup luksChangeKey -S 0`), а не удалять.

Заголовок стоит бэкапить после изменений слотов — `cryptsetup luksHeaderBackup`.
Копию охранять как recovery-ключ (внутри зашифрованный volume key) и держать вне
этой машины; восстановление вернёт слоты на момент снятия, включая удалённые.

Потом `my.secureboot.tpm2Unlock.enable = true`, `nh os switch`, reboot.
Флаг добавляет в crypttab initrd `tpm2-device=auto`: без него
systemd-cryptsetup не обязан пробовать токен из заголовка LUKS2.
`boot.initrd.systemd.enable = true` уже стоит (в `features/impermanence.nix`) —
без него unlock не сработает; на это есть ассерт.

Ожидаемое поведение при загрузке: спрашивают PIN (короткий), а не парольную
фразу LUKS. Если спрашивают именно парольную фразу — TPM отказал; смотреть
`journalctl -b -u systemd-cryptsetup@cryptroot`.

**8. Measured Boot (опционально).** Что он добавляет к шагу 7. PCR 7 запирает
только политику Secure Boot: любой UKI, подписанный *твоим* ключом, чип
устроит — включая старую генерацию с ядром, в котором с тех пор нашли дыру.
PCR 4 закрывает и это: в политику попадают только те UKI, что сейчас лежат на
ESP. То есть защита от откатов на подписанное, но устаревшее.

Руками PCR 4 непригоден — он меняется от каждого обновления ядра. Этим и
занимается `systemd-pcrlock`: он заранее считает, какими станут PCR у новых
генераций, и переписывает политику (она живёт в NV-индексе чипа) на каждый
switch. Токен LUKS при этом не перевыпускается — он ссылается на политику, а не
на конкретные значения PCR.

Проверить, что чип годится:

    sudo /run/current-system/systemd/lib/systemd/systemd-pcrlock is-supported

Затем `my.secureboot.measuredBoot.enable = true` и `nixos-rebuild boot`
(не `switch`: политику должен считать уже загруженный под ней initrd).
Перезагрузиться — нужен один boot, чтобы измерения PCR 4 и 7 стали настоящими,
— и только потом перевыпустить токен на политику:

    sudo systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=tpm2 \
      --tpm2-device=auto --tpm2-with-pin=yes \
      --tpm2-pcrlock=/var/lib/systemd/pcrlock.json

`--tpm2-pcrs` тут больше не нужен: политика pcrlock заменяет статическую
привязку к номерам PCR.

Что нужно знать до включения:

- `configurationLimit` автоматически падает до 8 — systemd-pcrlock не строит
  политику на большее число вариантов, это ассерт в модуле lanzaboote.
- `/var/lib/pcrlock.d` и `/var/lib/systemd` в persist: политика и измерения
  обязаны переживать reboot. Уже прописано.
- PCR 0 в `measuredBoot.pcrs` не входит намеренно — см. комментарий в
  `modules/nixos/features/secureboot.nix`. С ним каждое обновление прошивки
  требует `systemd-pcrlock unlock-firmware-code` до и `make-policy` после.
- `systemd-pcrlock` у systemd до сих пор помечен экспериментальным. Recovery-ключ
  из шага 7 обязателен, и шаг стоит последним: без него система полноценна.

## Куда девается сам конфиг

Короткий ответ: **папку надо хранить, она первична.** Из неё строится всё остальное.

- Свой ISO её *содержит* (`environment.etc."nixos-config".source = inputs.self`),
  но чтобы собрать ISO, папка уже нужна.
- После установки скрипт кладёт копию в `/home/andrey/Projects/cameo/os`
  на самом ноуте — оттуда ты потом делаешь `nh os switch`.
- Но это именно копия. Единственный правильный дом для конфига — **git-репозиторий
  с пушем на remote** (GitHub/Codeberg/свой forgejo). Смысл NixOS в том, что
  система воспроизводится из этого дерева; потерять его = потерять систему.

Поэтому шаг ноль, до всякой установки:

    cd <папка конфига>
    git init && git add -A
    git commit -m "initial: t14 laptop, niri, luks+btrfs, impermanence"
    git remote add origin git@github.com:<ты>/nixos.git && git push -u origin main

Секреты в репозиторий пушить безопасно: `secrets/secrets.yaml` зашифрован sops,
а приватные age-ключи в него не попадают (`.gitignore` их отсекает).

## Установка с флешки

Три пути. **A** не требует рабочего nix вообще нигде — начинай с него.

### A. Официальный minimal ISO + конфиг рядом на флешке

1. В Windows скачай
   `https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso`
2. Поставь **Ventoy** (`Ventoy2Disk.exe`) на флешку. Дальше это обычный диск:
   копируешь на него `.iso` **и** папку конфига рядом. Rufus тоже годится,
   но он затирает флешку целиком и места под конфиг не остаётся.
3. На T14: воткнуть флешку, **F12** — boot menu. Если её там нет — **F1** (UEFI Setup):
   - `Security → Secure Boot → Disabled` (включим обратно на шаге 6)
   - `Startup → UEFI/Legacy Boot → UEFI Only`
   - заодно сразу: `Config → Power → Sleep State → Linux`
4. Загрузился в live-систему:

        sudo -i
        nmtui                      # Wi-Fi; или iwctl, если nmtui нет
        lsblk                      # найти раздел флешки с конфигом, напр. /dev/sdb1
        mkdir -p /mnt/usb && mount /dev/sdb1 /mnt/usb
        cp -r /mnt/usb/nixos-config-backup /root/os

   Если пушил в git — проще: `nix-shell -p git --run "git clone <url> /root/os"`.

5. **Правка перед установкой** (`nano /root/os/hosts/laptop/disko.nix`):
   поставь реальный `device` из `lsblk` — на T14 это `/dev/nvme0n1`.

6. **Временный пароль.** sops ещё не настроен, поэтому в
   `modules/nixos/core/users.nix` закомментируй `hashedPasswordFile` и добавь:

        initialHashedPassword = "<вывод mkpasswd -m sha-512>";

   Без этого установишь систему, в которую не сможешь войти.

7. Разметка. **Сотрёт диск целиком.** disko интерактивно спросит пароль LUKS —
   это тот, что будешь вводить при загрузке (TPM подключим позже):

        nix --experimental-features "nix-command flakes" \
          run github:nix-community/disko -- \
          --mode destroy,format,mount --flake /root/os#laptop

8. Установка и перезагрузка:

        nixos-install --flake /root/os#laptop --no-root-passwd
        mkdir -p /mnt/persist/home/andrey/Projects/cameo
        cp -r /root/os /mnt/persist/home/andrey/Projects/cameo/os
        chown -R 1000:100 /mnt/persist/home/andrey
        reboot

   Флешку вынуть на перезагрузке.

9. Первая загрузка: LUKS-пароль → tuigreet → логин `andrey` с временным паролем →
   niri. Дальше README сверху, шаги 4-7 (sops, impermanence, Secure Boot, TPM).

### B. Свой ISO из этого флейка

Когда снова будет машина с рабочим nix. ISO уже содержит конфиг и скрипт
`install-laptop`, который делает шаги 5-8 за тебя:

    just iso                 # nix build .#installer-iso
    just iso-to-windows      # копирует в папку Downloads
    # записать Ventoy/Rufus, загрузиться, затем:
    sudo -i && install-laptop laptop

### C. nixos-anywhere по сети

Ноут грузится с официального minimal ISO, всё остальное делается по ssh
с другой машины — клавиатуру ноутбука трогать не надо вообще:

    just install <ip-ноутбука>

Нужен рабочий nix на управляющей машине и ssh-ключ, прописанный в
`users.users.root.openssh.authorizedKeys.keys` живого ISO.

## ThinkPad T14 Gen 1 (AMD) — что учтено

- `features/thinkpad.nix`: TrackPoint (скролл средней кнопкой), пороги заряда
  батареи 75/80 через `thinkpad_acpi` sysfs, `fan_control=1`.
  Пороги сделаны отдельным systemd-юнитом, а **не** TLP: TLP дерётся с
  power-profiles-daemon за `platform_profile`.
- `amd_pstate=active` — на Zen2-U даёт лучший энергопрофиль.
- LUKS с `bypassWorkqueues = true` (`hosts/laptop/disko.nix`): dm-crypt не
  прогоняет I/O через kworker'ы. На NVMe это меньше latency и больше IOPS;
  флаг попадает в crypttab initrd (`no-read-workqueue,no-write-workqueue`),
  применяется при следующей загрузке — уже открытый маппинг не меняется.
- Intel AX200: `power_save=0`, иначе лаги и просадки пропускной способности.
- Из `initrd` убран `thunderbolt` — у AMD-версии T14 Gen1 его нет
  (у Intel-версии есть, не перепутай при копировании конфига).
- dTPM 2.0 включён (`security.tpm2`) — база для шага 7.
- **Мусор в boot menu (F12).** Записи в NVRAM от прошлых систем (Windows
  Boot Manager, Limine, systemd-boot с уже несуществующего ESP) переразметку
  переживают — disko работает с диском, а не с переменными UEFI. Смотреть
  `sudo efibootmgr -v`, сверять PARTUUID из записи с `lsblk -o NAME,PARTUUID`,
  удалять несуществующие: `sudo efibootmgr -b 0000 -B`. Записи самой прошивки
  (Setup, Boot Menu, Lenovo Diagnostics, ThinkShield, USB CD/FDD/HDD, NVMe0,
  PXE BOOT) удалять бессмысленно — Lenovo пересоздаёт их при загрузке.
- **Сон:** в UEFI Setup поставь `Config → Power → Sleep State → Linux`.
  В режиме Windows ноут уходит только в s2idle и жрёт батарею в закрытом виде.
- **Отпечаток:** `services.fprintd` намеренно выключен. У части ревизий T14 Gen1
  стоит Synaptics, который libfprint не поддерживает (нужен закрытый
  python-validity, его в nixpkgs нет). Проверь `lsusb | grep -i synaptic`
  перед тем, как включать.
- Мерцание eDP: если поймаешь чёрные кадры, раскомментируй
  `amdgpu.dcdebugmask=0x10` в `hardware.nix` (отключает PSR).

## Сессия: niri + foot + fish

`my.profiles.niri.enable` даёт: niri, greetd/tuigreet вместо GDM, PipeWire,
порталы (gnome + gtk), polkit-агент, gnome-keyring.

Пользовательская часть — в `home/andrey/`:

- `niri.nix` — конфиг KDL целиком (`Mod` = Super): `Mod+Return` footclient,
  `Mod+D` walker, `Mod+Q` закрыть, `Mod+H/J/K/;` фокус, `Mod+R` пресеты ширины,
  `Print` скриншот. Плюс waybar, walker, mako, swayidle, cliphist.
  Раскладка `us,ru` переключается CapsLock (`grp:caps_toggle`); настоящий
  CapsLock — Shift+CapsLock.
- `terminal.nix` — foot в клиент-серверном режиме. Юнит `foot.service`
  (`foot --server`) поднимается с `graphical-session.target`, окна открывает
  `footclient` — на него смотрят и `Mod+Return`, и `terminal_cmd` в elephant.
  Выигрыш: шрифты и glyph-кэш живут в одном процессе, окно открывается
  мгновенно. Что нужно помнить:
  - после правок `foot.ini` — `systemctl --user restart foot`, сервер читает
    конфиг только при старте;
  - падение сервера уносит все окна разом (в юните `Restart=on-failure`);
  - app-id окон в этом режиме — `footclient`, а не `foot`: правила окон в
    `niri.nix` матчат оба;
  - дочерние процессы наследуют окружение systemd-сессии, а niri импортирует
    туда только `WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP NIRI_SOCKET`.
    Поэтому `NIXOS_OZONE_WL` продублирован в `systemd.user.sessionVariables`
    (`environment.d`) — иначе Electron, запущенный из терминала, уходил бы
    в XWayland.
- `launcher` (в `niri.nix`) — walker вместо fuzzel. Walker 2.x расщеплён на
  две части: GTK4-фронтенд `walker` и демон данных `elephant`, который по
  unix-сокету отдаёт приложения, `$PATH`, файлы, калькулятор и окна niri.
  Оба подняты systemd-юнитами (`walker --gapplication-service` зависит от
  `elephant.service`), `Mod+D` запускает клиент к уже живому процессу — как
  `footclient` к `foot --server`. Что нужно помнить:
  - набор провайдеров зашит в сборку: `pkgs.elephant.override
    { enabledProviders = [...]; }` — они собираются как Go-плагины (`.so`),
    так что список меняет и замыкание, и время сборки;
  - перезапуск сервисов автоматический: смена пакета видна sd-switch'у по
    `ExecStart`, а на конфиги (`elephant.toml`, `config.toml`, `style.css`)
    в юнитах вручную повешены `X-Restart-Triggers` — без них правка темы
    доезжала бы только до следующего логина;
  - префиксы запроса: `>` $PATH, `/` файлы, `=` калькулятор, `@` веб-поиск,
    `$` окна niri, `;` список провайдеров;
  - провайдер `symbols` (emoji, префикс `.`) выключен: его `.so` с вшитой
    базой весит 150 МиБ — треть замыкания. Нужен — добавь в список;
  - `elephant` читает `~/.config/elephant/elephant.toml`, а home-manager'овский
    `services.elephant.settings` кладёт `config.toml`, который никто не
    открывает — поэтому файл пишется через `xdg.configFile`;
  - историю запусков elephant держит в `~/.cache/elephant`; каталог добавлен
    в persist, иначе ранжирование сбрасывалось бы каждую загрузку;
  - clipboard тоже выключен: историю буфера ведёт `cliphist`;
  - тема (`services.walker.theme`) подменяет только `style.css`, разметку
    walker берёт из вшитых `layout.xml` / `item_*.xml`.
- `shell.nix` — fish (+ starship, fzf, zoxide, eza, direnv-хук).

niri — только композитор, панель/лаунчер/уведомления он не тянет, поэтому они
перечислены явно. `xwayland-satellite` стартует вместе с сессией, `DISPLAY=:0` —
без этого X11-приложения (Zoom, старый Electron) просто не запустятся.

Если захочешь типизированный конфиг вместо KDL-строки — есть input
`niri-flake` (sodiboo), он даёт `programs.niri.settings` с проверкой опций
и свежий niri из git. Миграция сводится к переписыванию одного файла.

## Бухгалтерия и КриптоПро: виртуалка с Windows

Что должно работать: кабинет ООО на nalog.ru с подписью КЭП (Рутокен),
Налогоплательщик ЮЛ и отчётность в СФР. Два последних существуют только под
Windows, а Wine для них плохой размен — у ФНС версии обновляются ежеквартально,
и первыми ломаются печать и обновление базы. Поэтому всё живёт в одной
Windows-VM: CryptoPro CSP, плагин CAdES, браузер, НП ЮЛ, СФР. Один токен, одно
место с криптой, одна лицензия CSP (она на установку, а не на человека).

Хостовая часть — `my.libvirt.enable`: libvirtd с qemu_kvm, swtpm (Windows 11 не
ставится без TPM 2.0), virt-manager и spice-редирект USB для проброса токена.
`/var/lib/libvirt` добавлен в persist — там и диски, и XML доменов, и состояние
эмулированного TPM.

### Как поднять

Один раз после `just switch`:

1. **Перелогиниться.** Пользователь попадает в группу `libvirtd`, а сессия
   узнаёт о новой группе только при следующем входе.
2. **Проверить, что persist доехал:** `findmnt /var/lib/libvirt` должен показать
   bind с `/persist`. Это не формальность: без него qcow2 гостя ляжет в tmpfs,
   то есть в оперативку, и исчезнет при перезагрузке.
3. **Поднять сеть libvirt.** NixOS кладёт определение сети `default`, но не
   запускает её — без этого `--network network=default` не найдёт сеть:

        sudo virsh net-autostart default
        sudo virsh net-start default

Дальше — образы и сама машина:

    just virtio-iso                                  # ISO с драйверами из nixpkgs
    just win-create ~/Downloads/win11.iso            # домен: q35, UEFI+SB, TPM 2.0, virtio
    just win                                         # запустить и открыть консоль
    just win-off                                     # штатно выключить

ISO Windows качается отдельно; если под рукой нет, `nix shell nixpkgs#quickemu -c
quickget windows 11` умеет это сам (сам quickemu как гипервизор тут не нужен).

Внутри установщика:

- на шаге выбора диска — **Load driver**, второй привод,
  `viostor\w11\amd64\viostor.inf`, иначе списка дисков не будет;
- сеть в установщике не нужна: LTSC пускает через OOBE без неё («настроить для
  организации» → «присоединиться к домену вместо этого»). Если всё же нужна —
  **Shift+F10** и `pnputil /add-driver D:\NetKVM\w11\amd64\netkvm.inf /install`
  (буква привода своя, их два);
- после установки — `virtio-win-guest-tools.exe` из корня привода: он ставит
  разом NetKVM, balloon, vioserial, qemu-ga и spice-агента (буфер обмена и
  подгон разрешения). Отдельно возиться с сетевым драйвером не придётся;
- если virtio-сеть капризничает, можно временно подсунуть гостю карту со
  встроенным в Windows драйвером и вернуть virtio позже:
  `virt-xml --connect qemu:///system win11 --edit --network model.type=e1000e`;
- язык интерфейса не важен, а вот **«Язык для программ, не поддерживающих
  Юникод» — русский**: софт СФР и часть форм НП ЮЛ до сих пор в cp1251, иначе
  кракозябры в отчётах и путях.

Токен пробрасывается уже в работающую машину: virt-manager → Add Hardware → USB
Host Device → `0a89:0025 Aktiv Rutoken lite`. Пока он отдан гостю, на хосте его
нет — это нормально и именно поэтому pcscd на хосте не нужен. Дальше внутри
Windows: CryptoPro CSP → серийник → «КриптоПро ЭЦП Browser plug-in» → браузер →
НП ЮЛ и софт СФР.

### Что нужно помнить

- Первое создание домена падало на `swtpm_setup ... exitstatus 1` без внятной
  причины в выводе: настоящая строка («Could not create directory for statedir»)
  лежит в `/var/log/swtpm`, куда пускают только root. swtpm подписывает EK- и
  platform-сертификаты своим локальным CA в `/var/lib/swtpm-localca`, а создать
  этот каталог от пользователя `tss` не может. Каталог теперь заводится
  tmpfiles-правилом в `features/libvirt.nix` и персистится.
- Автозапуск домена выключен намеренно: машина нужна несколько раз в год и
  подниматься вместе с ноутбуком не должна. `just win` стартует её сам, если
  она погашена.
- Токен в XML домена не прописан, поэтому подключается заново каждый сеанс
  (Add Hardware → USB Host Device). Надоест — прописать навсегда:
  `virt-xml --connect qemu:///system win11 --add-device --hostdev 0a89:0025,startupPolicy=optional`.
  `startupPolicy=optional` обязателен, иначе домен не стартует без воткнутого
  Рутокена.
- Перед обновлением CSP или НП ЮЛ имеет смысл скопировать диск. Снапшоты
  libvirt тут не помощники: внутренние не работают с UEFI-прошивкой на pflash,
  а внешние потом неудобно откатывать. Диск лежит на btrfs, поэтому копия
  бесплатна: `sudo cp --reflink=always /var/lib/libvirt/images/win11.qcow2
  /var/lib/libvirt/images/win11-$(date +%F).qcow2`.
- Диск гостя — состояние, которое флейк не воспроизводит. Он в
  `/var/lib/libvirt/images`, то есть в persist, но в бэкап его класть надо
  отдельно: там и лицензия CSP, и настроенный НП ЮЛ.
- `virtualisation.spiceUSBRedirection` ставит setuid-хелпер и даёт
  пользователю доступ к USB-устройствам вообще, не только к токену. На
  однопользовательском ноуте это разумный размен, но это именно размен.
  Не нужен hotplug — можно вместо него прописать `<hostdev>` в XML домена
  и выключить опцию.
- Домен воспроизводится рецептом `win-create`, но живёт всё равно императивно —
  как XML в `/var/lib/libvirt/qemu`, и правки из virt-manager в рецепт не
  возвращаются. Когда конфигурация устаканится, её стоит перенести в NixVirt
  (`github:AshleyYakeley/NixVirt`): домен описывается в Nix, состоянием остаётся
  только диск. Начинать сразу с него не стоит — иначе отлаживаешь одновременно
  Windows и генератор XML.
- Токен виден системе как `0a89:0025 Aktiv Rutoken lite`, но `services.pcscd`
  на хосте намеренно нет: он спорил бы с гостем за устройство. Понадобится
  проверить ридер вне виртуалки — временно включить pcscd и посмотреть
  `nix shell nixpkgs#pcsc-tools -c pcsc_scan -r`.

## Куда развивать дальше

Порядок примерно по соотношению «польза / затраченное время».

### Сначала — то, без чего конфиг неполноценен

- **git + remote.** См. раздел выше. До этого всё остальное бессмысленно.
- **`nix flake check` в CI.** Самое дешёвое улучшение: правка не попадает
  на ноут сломанной. Варианты — GitHub Actions с `DeterminateSystems/nix-installer-action`,
  либо **garnix** (подключается за две минуты, сам собирает и кэширует),
  либо self-hosted **buildbot-nix**.
- **`nixos-rebuild build-vm`.** Проверить сессию niri, greetd и логин в
  виртуалке за минуту, не трогая железо:

      nixos-rebuild build-vm --flake .#laptop && ./result/bin/run-laptop-vm

- **`nix-index` + `comma`.** `, htop` запускает пакет, не устанавливая его,
  и `command-not-found` начинает работать в fish.

### Когда захочется

- **nixos-facter** вместо ручного `hosts/laptop/hardware.nix`. Даёт
  машинно-читаемый снимок железа; `just install` уже умеет его генерировать.
  После этого файл сводится к `facter.reportPath = ./facter.json;`.
- **Бинарный кэш.** Пересобирать ядро и Helium на каждой машине надоедает
  быстро. **attic** — self-hosted, кладётся на любой VPS с S3;
  **cachix** — SaaS, бесплатен для open source. Подключается одной строкой
  в `nix.settings.substituters`.
- **Specialisation.** Второй пункт в загрузчике с другим набором опций —
  например `hardened` (ужесточённый ядерный профиль) или `no-tpm`
  (загрузка с паролем, если TPM-политика сломалась после обновления прошивки).
  Стоит почти ничего, а спасает от невозможности загрузиться.
- **Снапшоты /persist.** btrfs уже под ногами: `btrbk` или `snapper` +
  **restic**/**borg** на внешний диск. Импермансенс защищает от накопления
  мусора, но не от «удалил не то».
- **Гибернация.** Сейчас только zram, гибернации нет. Нужен swap-сабволюм
  внутри LUKS + `resumeDevice` + `boot.resumeOffset`. С Secure Boot и TPM
  это отдельная возня, но на ноуте вещь полезная.
- **niri-flake** (sodiboo) вместо KDL-строки: типизированный
  `programs.niri.settings`, ошибки ловятся на этапе eval, а не при логине.

### Дальний прицел

- **PCR 11 со signed policy** вместо PCR 7. Правильный TPM-режим: политика
  подписывается отдельным ключом, и обновление ядра перестаёт требовать
  переenroll'а. Lanzaboote это умеет (`--tpm2-public-key`), настройка
  заметно сложнее — переходить, когда PCR 7 начнёт раздражать.
- **Второй хост.** `mkHost "server"` + каталог в `hosts/`. Именно тут
  окупается разделение `modules/` ↔ `hosts/`: общие модули переиспользуются,
  хост остаётся списком флагов.
- **Dendritic pattern.** Каждый файл — flake-parts модуль, автоимпорт через
  `import-tree`, одна фича = один файл, который трогает и NixOS, и
  home-manager, и пакеты сразу. Элегантно, но переписывать структуру стоит,
  только когда текущая начнёт мешать.
- **clan.lol.** Целостный фреймворк поверх NixOS: секреты (vars), деплой,
  сеть между машинами из коробки. Имеет смысл при трёх и более хостах —
  забирает на себя ровно то, что к тому моменту успеет надоесть.
- **Свой модуль-абстракция для persist.** Когда список в
  `features/impermanence.nix` разрастётся, удобнее чтобы каждый модуль сам
  объявлял, что ему персистить (`my.persist.directories = [ ... ]`), а
  feature просто собирал это со всех модулей.

### Чего осознанно НЕ стоит делать

- **TLP** рядом с power-profiles-daemon — они дерутся за `platform_profile`.
  Выбери одно; на ThinkPad ppd + пороги заряда обычно достаточно.
- **`nixpkgs.config` внутри home-manager** при `useGlobalPkgs = true` —
  молча игнорируется, отладка занимает вечер.
- **Слепой `follows` на nixpkgs для всех инпутов.** Для home-manager он
  обязателен, а lanzaboote/disko иногда ломаются, если их прибить к
  чужому nixpkgs.
