{ pkgs, profile, ... }:

{

  imports = [
    ../profiles/${profile}.nix
  ];

  programs.home-manager.enable = true;
  home.packages = with pkgs; [
    neovim
    git
    tree
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "Quentin Roccia";
      user.email = "quentin@example.com";
    };
  };

  # You can add your own modules here.
}
