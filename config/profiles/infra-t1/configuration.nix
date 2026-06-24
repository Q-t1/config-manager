{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware.nix
    ../../modules/boot-efi.nix
    ../../modules/locale-fr.nix
    ../../modules/openssh.nix
    ../../modules/user-qt1-server.nix
  ];

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  nix.package = pkgs.nix;

  nixpkgs.config.allowUnfree = true;

  networking = {
    hostName = "infra-t1";
    useDHCP = false;
    dhcpcd.enable = false;
    useNetworkd = true;
    interfaces.enp5s0.useDHCP = true;
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
    firewall.allowedTCPPorts = [ 5900 ];
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        vulkan-tools
      ];
    };
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
    opengl.enable = true;
  };

  boot.kernelModules = [ "amdgpu" ];
  boot.initrd.kernelModules = lib.mkIf config.hardware.enableAllFirmware [ "amdgpu" ];

  services.xserver = {
    layout = "fr";
    videoDrivers = [ "amdgpu" ];
  };

  users.users.qt1.packages = with pkgs; [
    vulkan-tools
  ];

  programs.hyprland.enable = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session.command = "${pkgs.hyprland}/bin/Hyprland";
      default_session.user = "qt1";
    };
  };

  environment.systemPackages = [
    pkgs.wayvnc
    pkgs.kitty
  ];

  system.stateVersion = "25.11";
}
