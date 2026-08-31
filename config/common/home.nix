{ pkgs, ... }:

{
  programs.nh.enable = true;

  programs.home-manager.enable = true;
  home.packages = with pkgs; [
    nil
    nixd
    package-version-server

    curl
    wget

    ghostty.terminfo
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # Pin the ZLE keymap to emacs. zsh otherwise auto-selects vi keybindings
    # whenever $EDITOR/$VISUAL contains the substring "vi" — and "nvim" matches,
    # so the wsl profile's `defaultEditor = true` (EDITOR=nvim) silently flipped
    # the shell into vi-mode, where Ctrl-R is `redisplay` instead of
    # history-incremental-search-backward. Setting this makes the keymap
    # deterministic on every host regardless of $EDITOR.
    defaultKeymap = "emacs";
  };

  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Quentin R.";
        email = "quentin.roccia@gmail.com";
      };
      core.autocrlf = "input";
      core.eol = "lf";
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

  programs.zed-editor.installRemoteServer = {
    enable = true;
    extensions = [ "nix" ];
  };
}
