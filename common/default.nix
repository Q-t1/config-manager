{ pkgs, ... }:

{
  programs.home-manager.enable = true;
  home.packages = with pkgs; [
    neovim
    git
  ];

  programs.git = {
    enable = true;
    userName = "Quentin Roccia";
    userEmail = "quentin@example.com";
  };

  # You can add your own modules here.
}
