{
  description = "Qt1 Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      flake-utils,
      ...
    }:
    let
      lib = nixpkgs.lib;
      username = "qt1";
      stateVersion = "25.11";

      profilesDir = ./config/profiles;

      hosts = lib.mapAttrs (
        name: _:
        (import "${profilesDir}/${name}/host.nix") // {
          profile = name;
          homeDirectory = "/home/${username}";
        }
      ) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir profilesDir));

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

      mkHome =
        _: host:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${host.system};
          extraSpecialArgs = {
            inherit inputs username;
            inherit (host) profile system;
          };
          modules = [ (mkHmModule host) ];
        };

      mkNixos =
        _: host:
        lib.nixosSystem {
          system = host.system;
          specialArgs = {
            inherit inputs username;
            inherit (host) profile system;
          };

          modules = [
            inputs.determinate.nixosModules.default
            ./config/modules/nix-settings.nix
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
          ] ++ lib.optionals (host.kind == "nixos" && host.profile == "wsl") [
            inputs.nixos-wsl.nixosModules.wsl
          ];
        };

      homeHosts = lib.filterAttrs (_: host: host.kind == "home") hosts;

      allNixosHosts = lib.filterAttrs (_: host: host.kind == "nixos") hosts;

      systems = [ "aarch64-linux" "x86_64-linux" ];
    in
    flake-utils.lib.eachSystem systems (system: {
      formatter = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
    })
    // {
      homeConfigurations = lib.mapAttrs mkHome homeHosts;
      nixosConfigurations = lib.mapAttrs mkNixos allNixosHosts;
    };
}
