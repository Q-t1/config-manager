{ pkgs, ... }:

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

  security.pki.certificateFiles = [
    ./ssl/bleu-rootca.pem
  ];

  virtualisation.docker = {
    enable = true;
  };

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
    sops
    neovim
    cacert
    skopeo
    jq
    yq
    kubectl
    kubernetes-helm
  ];
}
