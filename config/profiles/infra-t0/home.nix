{ pkgs, ... }:

{

  home.packages = with pkgs; [
    ghostty.terminfo
  ];

  programs.zed-editor.installRemoteServer = {
    enable = true;
    extensions = [ "nix" ];
  };
}
