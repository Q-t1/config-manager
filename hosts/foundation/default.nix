{
  imports = [
    ../../modules/system/home.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "nix-foundation";
}
