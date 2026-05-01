{ pkgs, ... }:

{

  home.packages = with pkgs; [
    ghostty
    zed-editor
  ];

}
