{
  pkgs,
  lib,
  config,
  ...
}:

let
  # Catppuccin Mocha (mauve accent) for yazi — matches the Neovim IDE's
  # colorscheme (nvim.nix) and the zellij chrome, so editor, picker and
  # multiplexer share one palette. Catppuccin ships a plain per-accent theme.toml
  # (not the yazi flavor-package format), so read it straight into
  # programs.yazi.theme; swap the filename for another accent under themes/mocha/.
  catppuccinYaziTheme = builtins.fromTOML (
    builtins.readFile "${
      pkgs.fetchFromGitHub {
        owner = "catppuccin";
        repo = "yazi";
        rev = "d62802be39210ea10e54b3e3b09735c6cb9e57c1";
        hash = "sha256-bwzEO8exoBwa19q+jnYjHkaamGl2mhfukIEhDfUCRGI=";
      }
    }/themes/mocha/catppuccin-mocha-mauve.toml"
  );

  nvimBin = "${config.programs.nixvim.build.package}/bin/nvim";
  zellijBin = "${pkgs.zellij}/bin/zellij";

  # The `coding` layout puts yazi (left) and Neovim (right) in separate zellij
  # panes, so opening a file means handing it from one pane to the other. The
  # bridge is a Neovim server socket: Neovim listens on it, and yazi's `edit`
  # opener sends the picked file with `nvim --server <sock> --remote`.
  #
  # The socket PATH is derived independently in each pane from the tab's start
  # directory ($PWD at launch, identical for both panes and stable even after you
  # cd around inside yazi). Deriving it rather than exporting it is deliberate:
  # panes spawned by `zellij action new-tab` do not reliably inherit the
  # launcher's environment, so a shared env var could not be trusted — a hash of
  # the start dir can. Different projects hash to different sockets, so multiple
  # `coding` tabs never cross their bridges.
  codingSockSnippet = ''
    sock="''${XDG_RUNTIME_DIR:-/tmp}/nvim-coding-$(printf '%s' "$PWD" | ${pkgs.coreutils}/bin/sha1sum | ${pkgs.coreutils}/bin/cut -c1-16).sock"
  '';

  # Left pane: yazi, with the target socket exported so its `edit` opener (a
  # child process) still points at this tab's Neovim after you navigate in yazi.
  codingYazi = pkgs.writeShellScript "coding-yazi" ''
    ${codingSockSnippet}
    export YAZI_NVIM_SOCK="$sock"
    exec ${config.programs.yazi.finalPackage}/bin/yazi "$@"
  '';

  # Right pane: Neovim listening on that socket. rm -f clears a stale socket left
  # by a crash; because a different project hashes elsewhere, it never disturbs
  # another running IDE.
  codingNvim = pkgs.writeShellScript "coding-nvim" ''
    ${codingSockSnippet}
    rm -f "$sock"
    exec ${nvimBin} --listen "$sock" "$@"
  '';
in
{
  imports = [ ./nvim.nix ];

  home.packages = with pkgs; [
    skopeo
    jq
    yq
    kubectl
    kubernetes-helm
    kustomize
    kubeconform
    openssl
    fluxcd
    claude-code
    fd # yazi's file finder (the `coding` left pane)
    ripgrep # yazi's content search
  ];

  programs.git.settings.user.email = lib.mkForce "quentin.roccia@bleucloud.fr";

  programs.firefox = {
    enable = true;
    policies.Certificates.Install = [ "${./certs/bleu-rootca.pem}" ];
    profiles.default = {
      search = {
        default = "google";
        force = true;
      };
      settings = {
        "layers.acceleration.disabled" = true;
        "gfx.webrender.compositor" = false;
      };
    };
  };

  # Certificates.Install policy doesn't persist to the NSS db on Linux;
  # import directly via certutil on every home-manager activation instead.
  home.activation.firefoxTrustBleuCA = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ffProfile="${config.home.homeDirectory}/${config.programs.firefox.profilesPath}/default"
    certFile="${./certs/bleu-rootca.pem}"
    if [[ -d "$ffProfile" ]] && [[ -f "$ffProfile/cert9.db" ]]; then
      if ! ${pkgs.nss.tools}/bin/certutil -L -d "$ffProfile" 2>/dev/null | grep -q "bleu.local"; then
        run ${pkgs.nss.tools}/bin/certutil -A \
          -n "bleu.local-SUBCA1-Issuing-CA" \
          -t "CT,C,C" \
          -i "$certFile" \
          -d "$ffProfile"
      fi
    fi
  '';

  programs.zsh.shellAliases.ff = "MOZ_ENABLE_WAYLAND=1 firefox &>/dev/null & disown";

  # Free Ctrl-S / Ctrl-Q from XON/XOFF flow control so the save keybind never
  # freezes an interactive terminal, and provide the `coding` launcher.
  programs.zsh.initContent = ''
    [[ $- == *i* ]] && stty -ixon 2>/dev/null

    # `coding [target]` opens the IDE inside a zellij "coding" layout (yazi file
    # pane on the left, Neovim + a shell strip on the right), rooted at the target
    # so yazi, the LSP and telescope all use that project. A file target skips the
    # layout and just edits the file (keeps single-file / $EDITOR-style use fast).
    # Inside an existing zellij session it adds a tab instead of nesting.
    coding() {
      local target="''${1:-.}"
      if [[ -f "$target" ]]; then
        nvim -- "$target"
        return
      fi
      local dir="''${target:A}" # zsh: resolve to an absolute path
      local tab_name="coding: ''${dir:t}"
      if [[ -n "$ZELLIJ" ]]; then
        zellij action new-tab --layout coding --cwd "$dir" --name "$tab_name"
      else
        local session_name="coding-''${dir:t}"
        if zellij list-sessions 2>/dev/null | grep -qF "$session_name"; then
          ( builtin cd -- "$dir" && zellij attach "$session_name" )
        else
          local tmp_layout
          tmp_layout=$(mktemp --suffix=.kdl)
          cat > "$tmp_layout" <<KDL
    layout {
        session {
            name "$session_name"
        }
        tab name="$tab_name" focus=true {
            pane split_direction="vertical" {
                pane size="24%" name="files" focus=true {
                    command "${codingYazi}"
                }
                pane split_direction="horizontal" {
                    pane size="80%" name="editor" {
                        command "${codingNvim}"
                    }
                    pane size="20%" name="terminal"
                }
            }
        }
    }
    KDL
          ( builtin cd -- "$dir" && zellij --layout "$tmp_layout" )
          rm -f "$tmp_layout"
        fi
      fi
    }
  '';

  # yazi is the IDE's file manager, running as the persistent left pane of the
  # `coding` zellij layout (below). Picking a file opens it in the Neovim pane on
  # the right over a server socket (see the `edit` opener and the layout).
  programs.yazi = {
    enable = true;

    # No shell wrapper: yazi is the IDE's file pane, not a `y`-to-cd shell
    # command, so the zsh integration would only add noise.
    enableZshIntegration = false;

    settings = {
      mgr = {
        # Collapse yazi to a single column (parent + preview off). In a narrow
        # sidebar this reads like a file tree, and the content preview is
        # redundant anyway — the file's contents show in the Neovim pane.
        ratio = [
          0
          1
          0
        ];
        show_hidden = true; # dotfiles matter in a Nix repo (.rtk, .git-ignored…)
        sort_dir_first = true;
      };

      # Open (Enter) hands the file to this tab's Neovim over its socket, then
      # moves zellij focus right so you land in the editor. block=false keeps
      # yazi running as the sidebar instead of suspending it. The prepend rule
      # routes every file through this opener (yazi enters directories itself, so
      # they never reach it); $YAZI_NVIM_SOCK is exported by the coding-yazi
      # wrapper and resolves to the same socket the Neovim pane listens on.
      #
      # realpath makes the path absolute first: yazi may hand the opener a path
      # relative to *its* cwd, but `nvim --remote` resolves relative paths against
      # the editor's cwd — so once you've navigated into a subdirectory in yazi,
      # a bare name would open the wrong file (or a new empty one). $1 is the
      # hovered file (openers run via `sh -c`, files as positional args).
      opener.edit = [
        {
          run = "${nvimBin} --server \"$YAZI_NVIM_SOCK\" --remote \"$(${pkgs.coreutils}/bin/realpath -- \"$1\")\" && ${zellijBin} action move-focus right";
          desc = "Open in Neovim (right pane)";
          block = false;
        }
      ];
      open.prepend_rules = [
        {
          url = "*";
          use = "edit";
        }
      ];
    };

    # Catppuccin Mocha (mauve) — see the let binding at the top of this file.
    theme = catppuccinYaziTheme;
  };

  programs.zellij = {
    enable = true;

    settings = {
      # Catppuccin Mocha — a zellij built-in theme, matched to the Neovim IDE's
      # colorscheme (nvim.nix) so the editor and the surrounding zellij chrome
      # share one palette.
      theme = "catppuccin-mocha";

      # Mouse drag-select in a (non-Neovim) pane copies straight to the Windows
      # clipboard via clip.exe — reliable regardless of WSLg's Wayland state.
      # Neovim panes keep their own mouse handling (mouse=a), since Neovim
      # requests mouse tracking and zellij forwards events to it.
      mouse_mode = true;
      copy_on_select = true;
      copy_command = "clip.exe";
    };

    # VSCode-style IDE workspace launched by the `coding` shell function:
    #
    #   ┌ files ┐┌──────── editor (nvim) ────────┐
    #   │ yazi  ││                               │
    #   │       │├────────── terminal ───────────┤
    #   └───────┘└───────────────────────────────┘
    #
    # yazi is the file manager in a persistent left pane; Neovim fills the right,
    # with a shell strip beneath it. Every pane starts in the project directory
    # (`coding` passes it as the tab cwd), so the editor, terminal and yazi all
    # root there. Focus starts in yazi so you begin by browsing; Enter on a file
    # opens it in the editor and hops focus right (see the `edit` opener above).
    #
    # The panes run wrappers, not bare `nvim`/`yazi`, so the two ends of the
    # file-open bridge agree on a socket (see codingNvim / codingYazi at the top
    # of this file). The shell strip is named "terminal" (instead of zellij's
    # default "Pane #2"); Alt-t stacks more terminals onto it VSCode-style (see
    # keybinds below).
    layouts.coding = ''
      layout {
          tab name="code" focus=true {
              pane split_direction="vertical" {
                  pane size="24%" name="files" focus=true {
                      command "${codingYazi}"
                  }
                  pane split_direction="horizontal" {
                      pane size="80%" name="editor" {
                          command "${codingNvim}"
                      }
                      pane size="20%" name="terminal"
                  }
              }
          }
      }
    '';

    # zellij is modal and, in its Normal mode, intercepts a handful of Ctrl
    # chords before the running app sees them — several of which the nixvim IDE
    # (nvim.nix) relies on, most importantly Ctrl-s (save). Free those in Normal
    # mode so they reach Neovim:
    #   Ctrl-s save · Ctrl-p quick-open / blink prev · Ctrl-n blink next ·
    #   Ctrl-h seamless split/pane nav across Neovim and zellij (see nvim.nix)
    # zellij keeps everything else, driven from its Alt bindings (Alt-n new
    # pane, Alt-h/j/k/l move focus, Alt-+/- resize, Alt-f float, Alt-[/] cycle
    # layouts) plus Ctrl-g lock, Ctrl-t tab, Ctrl-o session, Ctrl-q quit.
    #
    # Alt-t is added below: a VSCode-style "new terminal" that opens another
    # shell — also named "terminal" — stacked in the bottom "terminal" pane. It
    # drops focus down first so the new shell lands in the terminal region even
    # when invoked from the editor, then stacks it; move between the stacked
    # terminals with Alt-j/k.
    extraConfig = ''
      keybinds {
          normal {
              unbind "Ctrl s"
              unbind "Ctrl p"
              unbind "Ctrl n"
              unbind "Ctrl h"

              // VSCode-style "new terminal": focus the bottom terminal region,
              // then open another shell (also named "terminal") stacked onto
              // it. Repeat to grow the stack; cycle the terminals with Alt-j/k.
              bind "Alt t" { MoveFocus "Down"; NewPane { name "terminal"; stacked true; }; }
          }
      }
    '';
  };
}
