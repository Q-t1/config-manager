{ pkgs, config, ... }:

{
  wsl = {
    enable = true;
    defaultUser = "qt1";
  };

  nixpkgs.config.allowUnfree = true;

  boot.kernelModules = [ "kvm-intel" ];

  virtualisation.docker = {
    enable = true;
    # Daemon is socket-activated instead of started at boot.
    enableOnBoot = false;
  };

  # WSLg publishes its Wayland socket outside XDG_RUNTIME_DIR; link it in so
  # WAYLAND_DISPLAY=wayland-0 resolves. %t expands to /run/user/$UID.
  systemd.user.tmpfiles.rules = [
    "L+ %t/wayland-0      - - - - /mnt/wslg/runtime-dir/wayland-0"
    "L+ %t/wayland-0.lock - - - - /mnt/wslg/runtime-dir/wayland-0.lock"
  ];

  security.pki.certificateFiles = [
    ./certs/bleu-rootca.pem
  ];

  users.extraUsers.qt1 = {
    isNormalUser = true;
    home = "/home/qt1";
    extraGroups = [
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
  };

  system.stateVersion = "26.05";

  services.dbus.enable = true;

  programs.zsh.enable = true;

  environment.etc."containers/policy.json".text = builtins.toJSON {
    default = [
      { type = "insecureAcceptAnything"; }
    ];
    transports = {
      "docker-daemon" = {
        "" = [ { type = "insecureAcceptAnything"; } ];
      };
    };
  };

}
