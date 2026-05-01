{
  imports = [
    ../../modules/system/default.nix
  ];
  home-manager.users.qt1 = import ../../home/qt1/default.nix;
  networking.hostName = "orbstack";
}
