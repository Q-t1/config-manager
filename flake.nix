{
  description = "Qt1 Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, sops-nix, ... }:
    let
      lib = nixpkgs.lib;
      username = "qt1";
      stateVersion = "25.11";

      hosts = {
        orbstack = {
          system = "aarch64-linux";
          profile = "orbstack";
          homeDirectory = "/home/${username}";
          kind = "home";
        };

        infra-t0 = {
          system = "x86_64-linux";
          profile = "infra-t0";
          homeDirectory = "/home/${username}";
          kind = "nixos";
        };

        infra-t1 = {
          system = "x86_64-linux";
          profile = "infra-t1";
          homeDirectory = "/home/${username}";
          kind = "nixos";
        };

        wsl = {
          system = "x86_64-linux";
          profile = "wsl";
          homeDirectory = "/home/${username}";
          kind = "nixos";
        };
      };

      mkHmModule = host: {
        imports = [
          ./config/common/home.nix
          ./config/profiles/${host.profile}/home.nix
        ];
        home = {
          inherit username stateVersion;
          homeDirectory = host.homeDirectory;
        };
        programs.home-manager.enable = true;
      };

      mkHome = _: host:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${host.system};
          extraSpecialArgs = {
            inherit inputs username;
            inherit (host) profile system;
          };
          modules = [ (mkHmModule host) ];
        };

      mkNixos = _: host:
        lib.nixosSystem {
          system = host.system;
          specialArgs = {
            inherit inputs username;
            inherit (host) profile system;
          };
          modules = [
            inputs.nixos-wsl.nixosModules.wsl
            sops-nix.nixosModules.sops
            ./config/profiles/${host.profile}/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit inputs username;
                inherit (host) profile system;
              };
              home-manager.users.${username} = mkHmModule host;
            }
          ];
        };

      homeHosts =
        lib.filterAttrs (_: host: host.kind == "home") hosts;

      allNixosHosts =
        lib.filterAttrs (_: host: host.kind == "nixos") hosts;
    in
    {
      homeConfigurations = lib.mapAttrs mkHome homeHosts;
      nixosConfigurations = lib.mapAttrs mkNixos allNixosHosts;
    };
}