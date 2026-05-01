# modules/system/home/defaults.nix
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    neovim
    git
  ];

  programs.git = {
    enable = true;
    userName = "Quentin";
    userEmail = "quentin@example.com";
  };

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-unwrapped;
    vimAlias = true;
    viAlias = true;
  };
}
