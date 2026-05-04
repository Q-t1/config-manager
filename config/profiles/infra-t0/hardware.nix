{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/2c29afce-ddce-407c-88f3-33d3057f8f2b";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/DA00-2F87";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  fileSystems."/var/lib/kubelet/pods/3d0b373e-f8ab-43ec-b1b1-f08ce3e91c2f/volumes/kubernetes.io~projected/kube-api-access-lxpnz" =
    {
      device = "tmpfs";
      fsType = "tmpfs";
    };

  fileSystems."/var/lib/kubelet/pods/ba92d140-eac5-4bc4-8c39-42c406de7b70/volumes/kubernetes.io~projected/kube-api-access-ljz97" =
    {
      device = "tmpfs";
      fsType = "tmpfs";
    };

  fileSystems."/var/lib/kubelet/pods/d64680ef-9eea-4f4f-80c8-bcfcc79053ac/volumes/kubernetes.io~projected/kube-api-access-bcplg" =
    {
      device = "tmpfs";
      fsType = "tmpfs";
    };

  swapDevices = [
    { device = "/dev/disk/by-uuid/d2f46cf7-fb17-4fb1-8b8d-e5deb56458aa"; }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
