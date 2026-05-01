{ inputs, lib, config, pkgs, ... }:

{
  users.users.qt1 = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    home = "/home/qt1";
  };
}
