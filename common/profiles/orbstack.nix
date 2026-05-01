{ pkgs, ... }:

{

  home.packages = with pkgs; [
    neovim
    git
    tree
  ];

}
