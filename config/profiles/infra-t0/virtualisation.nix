{ pkgs, ... }:

{

  virtualisation.incus = {
    enable = true;
    ui = {
      enable = true;
    };
    package = pkgs.incus;
    bucketSupport = false;
    preseed = {
      networks = [
        {
          config = {
            "ipv4.address" = "10.0.0.1/24";
            "ipv4.nat" = "true";
          };
          name = "incusbr0";
          type = "bridge";
        }
      ];
      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              network = "incusbr0";
              type = "nic";
            };
            root = {
              path = "/";
              pool = "default";
              size = "20GiB";
              type = "disk";
            };
          };
        }
        {
          name = "lan";
          description = "LAN bridged VMs";
          devices = {
            eth0 = {
              name = "eth0";
              nictype = "bridged";
              parent = "br-lan";
              type = "nic";
            };
            root = {
              path = "/";
              pool = "default";
              size = "20GiB";
              type = "disk";
            };
          };
        }
      ];
    };
  };
  networking.nftables.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    8443
  ];
  networking.firewall.trustedInterfaces = [ "incusbr0" ];

  boot.kernelModules = [
    "overlay"
    "br_netfilter"
  ];

  # Runtime config via systemd override
  systemd.services.incus-post-init = {
    description = "Incus HTTPS config";
    serviceConfig = {
      User = "root";
    };
    after = [ "incus.service" ];
    requires = [ "incus.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.incus ];
    script = ''
      incus config set core.https_address ":8443" || true
      incus config trust add-certificate /opt/incus/incus-ui.crt || true
      if ! incus storage list | grep -q default; then
        echo "No default pool. Proceed to creation."
        incus storage create default btrfs source=/incus-pool
        incus config set storage.default_pool default
      else
        echo "Default pool already exists. Skipping creation..."
      fi
    '';
  };

}
