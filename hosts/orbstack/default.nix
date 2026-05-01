{
  imports = [
  ];
  home-manager.users.quentin = import ../../modules/system/home.nix;
  networking.hostName = "orbstack";
}
