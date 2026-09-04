{
  disko.devices = {
    disk.main = {
      device = "/dev/nvme0n1";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            name = "ESP";
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings = {
                allowDiscards = true;
                bypassWorkqueues = true;
                # crypttab-опция: понадобится для TPM2-unlock на шаге 7.
                # tryEmptyPassphrase = false;
              };
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  "--csum"
                  "xxhash"
                ];
                subvolumes =
                  let
                    opts = [
                      "compress=zstd:1"
                      "noatime"
                    ];
                  in
                  {
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = opts;
                    };
                    "@persist" = {
                      mountpoint = "/persist";
                      mountOptions = opts;
                    };
                    "@log" = {
                      mountpoint = "/var/log";
                      mountOptions = opts;
                    };
                  };
              };
            };
          };
        };
      };
    };

    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=4G"
        "mode=755"
        "defaults"
      ];
    };
  };
}
