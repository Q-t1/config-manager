{ pkgs, ... }:

{

  home.packages = with pkgs; [
    nil
    ghostty.terminfo
  ];

  programs.zed-editor.installRemoteServer = {
    enable = true;
    extensions = [ "nix" ];
  };
}
