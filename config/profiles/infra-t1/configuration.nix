{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware.nix
  ];

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

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

  time.timeZone = "Europe/Paris";

  console.keyMap = "fr";

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
    opengl = {
      enable = true;
    };
  };

  boot.kernelModules = [ "amdgpu" ];

  services.xserver = {
    layout = "fr";
    videoDrivers = [ "amdgpu" ];
  };

  boot.initrd.kernelModules = lib.mkIf config.hardware.enableAllFirmware [ "amdgpu" ];

  programs.zsh.enable = true;

  services = {
    openssh = {
      enable = true;
      settings = {
        PubkeyAuthentication = "yes";
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };
  };

  users.users.qt1 = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "incus-admin"
      "video"
      "render"
    ];
    packages = with pkgs; [
      vulkan-tools
    ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDtASdfLMatnUWsdJIjIvIXqXrnmABAznN/6mji1/rzRLqrusduqahyi4htTRvOuue3vrhUqeywiRTNTpzthfhVqeF5WehE1wAPkbgGwAvxC8ltqLPza6KkfZF0WXdXj/MsKJDTJUwui+acbyJocuMz0teJOhURoaEetXzr+ffj6P9Txz7uX6KN8D2DYGi9WvG8QPdlF/89f5vtCx4GFrKkdSET+yNC3PEcf+X8wDoL+ztuvcTGLb4rC42NzLJ82VCAYZ6KS085s8GD+lcgU/jxpRUeCVoY7Ciym/VKs2oxVsyM45fP+d33BJmqV+WGgVLHz0T4y05HOS6CBLObbXZYLfDg7jNl/MVxVktNRfvPLr23z8IvUL1DR8lHIqc6jesFMe8W5PuaoxwzQIhRl8ywGT/rVq1btMiS41mqo/86pZAFtehTt04A3GbMVGB7NNO3tmaVbUlr/aSFdB/hLr0pU3uuZQsHCipZ/3+IGs7erU1r2VVNhnxd/JcDJEVstd8= quentin@MacBook-Air-de-Quentin.local"
    ];
  };

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
