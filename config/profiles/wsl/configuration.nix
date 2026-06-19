{ pkgs, config, ... }:

{
  wsl = {
    enable = true;
    defaultUser = "qt1";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

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

  services.dbus.enable = true;

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    cacert
    skopeo
    jq
    yq
    kubectl
    kubernetes-helm
    openssl
    fluxcd
  ];

}
