{ ... }: {
  services.openssh = {
    enable = true;

    passwordAuthentication = false;
    kbdInteractiveAuthentication = false;
    challengeResponseAuthentication = false;

    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];

    knownHosts = {
      "github.com".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    }
  };
}
