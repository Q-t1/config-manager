{
  imports = [
    ./hardware-configuration.nix
  ];
  home-manager.users.quentin = import ../../modules/system/home.nix;
  networking.hostName = "nix-foundation";
}
