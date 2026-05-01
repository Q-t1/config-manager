{ pkgs, ... }:

{

  home.packages = with pkgs; [
    ghostty-bin
    zed-editor
  ];

}
