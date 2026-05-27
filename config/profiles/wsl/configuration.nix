{ pkgs, config, ... }:

{
  wsl = {
    enable = true;
    defaultUser = "qt1";
  };


  sops = {
    age.keyFile = "/home/qt1/.config/sops/age/keys.txt";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.kernelModules = [ "kvm-intel" ];

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

  sops.secrets.tlsCert = {
    sopsFile = ./secrets/bleu-rootca.yaml;
    owner = "root";
    mode = "0444";
  };

  environment.etc."pki/tls/certs/bleu-rootca.pem".source =
    config.sops.secrets.tlsCert.path;

  environment.variables.CURL_CA_BUNDLE = "/etc/pki/tls/certs/bleu-rootca.pem";

}
