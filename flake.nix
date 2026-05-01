{
  description = "NixOS config for orbstack + foundation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      hosts = {
        orbstack = {
          system = "aarch64-linux";
        };
        foundation = {
          system = "x86_64-linux";
        };
      };

      mkHost = name:
        nixpkgs.lib.nixosSystem {
          system = hosts.${name}.system;
          specialArgs = { inherit inputs name; };
          modules = [
            ./hosts/${name}/default.nix
            home-manager.nixosModules.home-manager
          ];
        };
    in {
      nixosConfigurations = {
        orbstack = mkHost "orbstack";
        foundation = mkHost "foundation";
      };
    };
}
