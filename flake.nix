{
  description = "Qt1 Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, home-manager, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        username = "qt1";  # your user
      in
      {
        homeConfigurations."${username}@${system}" =
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs username;
            homeDirectory = "/home/${username}";
            stateVersion = "25.11";

            modules = [
              ./common/default.nix
            ];
          };
      });
}
