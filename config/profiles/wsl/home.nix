{ config, pkgs, lib, ... }:

{
  programs.zsh.shellAliases = {
    chrome = "chromium >> /dev/null 2>&1 &";
  };

  programs.zellij = {
    enable = true;
  };

  programs.chromium = {
    enable = true;
  };

}
