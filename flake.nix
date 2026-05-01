{
  description = "Qt1 Home Manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      username = "qt1";
      mkHome = { profile, system }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = {
            inherit profile system username;
          };
          modules = [
            ./common/default.nix
          ];

          # Non‑module-level items (would be overridden by modules anyway)
          config.home.username = username;
          config.home.homeDirectory = "/home/${username}";
          config.home.stateVersion = "25.11";
          config.programs.home-manager.enable = true;
        };
    in
    {
      homeConfigurations = {
        orbstack = mkHome {
          profile = "orbstack";
          system = "aarch64-linux";
        };

        foundation = mkHome {
          profile = "foundation";
          system = "x86_64-linux";
        };

        wsl = mkHome {
          profile = "wsl";
          system = "x86_64-linux";
        };
      };
    };
}
