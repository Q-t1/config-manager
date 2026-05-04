{ pkgs, profile, ... }:

{

  imports = [
    ../profiles/${profile}/home.nix
  ];

  programs.nh.enable = true;

  programs.home-manager.enable = true;
  home.packages = with pkgs; [
    nil
    nixd
    package-version-server

    curl
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.git = {
    enable = true;

    settings = {
      user.name = "Quentin Roccia";
      user.email = "quentin@example.com";

      push.autoSetupRemote = true;
      push.default = "current";
      init.defaultBranch = "main";
    };
  };

  programs.neovim = {
    enable = true;

    withPython3 = false;
    withRuby = false;

    vimAlias = true;
    viAlias = true;
  };
}
