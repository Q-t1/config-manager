# modules/system/home/defaults.nix
{ config, pkgs, ... }:

{

  home.username = "qt1";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    neovim
    git
  ];

  programs.git = {
    enable = true;
    userName = "qt1";
    userEmail = "qt1@example.com";
  };

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-unwrapped;
    vimAlias = true;
    viAlias = true;
  };
}
