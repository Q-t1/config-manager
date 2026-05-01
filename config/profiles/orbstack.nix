{ pkgs, ... }:

{

  home.packages = with pkgs; [
    ghostty.terminfo
    zed-editor.remote_server
  ];

}
