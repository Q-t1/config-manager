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

      mkHome = { profile, system, homeDirectory ? "/home/${username}" }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};

          extraSpecialArgs = {
            inherit profile system username;
          };

          modules = [
            ./config/common/default.nix

            {
              home = {
                inherit username homeDirectory;
                stateVersion = "25.11";
              };

              programs.home-manager.enable = true;
            }
          ];
        };
    in
    {
      homeConfigurations = {
        orbstack = mkHome {
          profile = "orbstack";
          system = "aarch64-darwin";
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
