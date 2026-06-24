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
  };

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
