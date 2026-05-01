{ inputs, lib, config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    git
  ];

  programs.git = {
    enable = true;
    userName = "Qt1";
    userEmail = "quentin.roccia@gmail.com";
  };

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-unwrapped;
    vimAlias = true;
    viAlias = true;
  };
}
