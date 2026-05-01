{ pkgs, ... }:

{

  environment.systemPackages = [
    pkgs.ghostty.terminfo
  ];

  home.packages = with pkgs; [
    zed-editor
  ];

}
