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
  lazygitBin = "${pkgs.lazygit}/bin/lazygit";

  # KDL layout template for per-file tabs. At runtime, open-file-in-tab
  # substitutes __NAME__ (tab label) and __FILE__ (absolute path for nvim).
  zellijFileTabLayout = pkgs.writeText "zellij-file-tab.kdl" ''
    layout {
        default_tab_template {
            pane size=1 borderless=true {
                plugin location="zellij:tab-bar"
            }
            children
            pane size=1 borderless=true {
                plugin location="file:${pkgs.zellijPlugins.zjstatus}" {
                    format_left   "#[fg=#cba6f7,bold] {session} "
                    format_center ""
                    format_right  "{command_git_branch}{datetime}"

                    command_git_branch {
                        command  "bash"
                        args     "-c" "git -C #{cwd} branch --show-current 2>/dev/null"
                        format   "#[fg=#a6e3a1]  {stdout} "
                        interval "5"
                    }

                    datetime {
                        format   "#[fg=#6c7086,italic] %H:%M "
                        timezone "Europe/Paris"
                    }
                }
            }
        }
        tab name="__NAME__" focus=true {
            pane {
                command "${nvimBin}"
                args "__FILE__"
            }
        }
    }
  '';

  # Opens $1 in a fresh Zellij tab with its own Neovim instance. Yazi's `edit`
  # opener calls this so Zellij's tab bar becomes the "open files" list instead
  # of bufferline inside Neovim. Extra args (e.g. +42) are passed to nvim.
  openFileInTab = pkgs.writeShellScript "open-file-in-tab" ''
    file=$(${pkgs.coreutils}/bin/realpath -- "$1")
    name=$(${pkgs.coreutils}/bin/basename -- "$file")
    dir=$(${pkgs.coreutils}/bin/dirname -- "$file")
    layout=$(${pkgs.coreutils}/bin/mktemp --suffix=.kdl)
    ${pkgs.gnused}/bin/sed \
      -e "s|__NAME__|$name|" \
      -e "s|__FILE__|$file|" \
      "${zellijFileTabLayout}" > "$layout"
    ${zellijBin} action new-tab --layout "$layout" --cwd "$dir"
    ${pkgs.coreutils}/bin/rm -f "$layout"
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
    ripgrep # yazi's content search and `fif` function
    lazygit # full git UI; also used by the `git` zellij layout
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
        local _sessions
        _sessions=$(zellij list-sessions 2>/dev/null)
        # A live session has the name but no EXITED marker; an exited one shows
        # "(EXITED - attach to resurrect)" — attaching resurrects it as a bare
        # shell without the layout, which is the "run twice" bug. Delete the
        # zombie and start fresh instead.
        local _live
        _live=$(echo "$_sessions" | grep -F "$session_name" | grep -vi 'EXITED')
        if [[ -n "$_live" ]]; then
          ( builtin cd -- "$dir" && zellij attach "$session_name" )
        else
          zellij delete-session "$session_name" 2>/dev/null
          # Use -n/--new-session-with-layout, NOT --layout: with -s present,
          # `--layout coding` means "add a tab to session coding-<dir>", which
          # doesn't exist yet, so zellij errors "Session not found". -n always
          # starts a new session, so it composes with -s.
          ( builtin cd -- "$dir" && zellij -s "$session_name" -n coding )
        fi
      fi
    }

  # `gitview [dir]` opens a dedicated git tab (full-screen lazygit). Inside
  # an existing zellij session it adds a tab; outside it starts a new session.
  gitview() {
    local target="''${1:-.}"
    local dir="''${target:A}"
    local tab_name="git: ''${dir:t}"
    if [[ -n "$ZELLIJ" ]]; then
      zellij action new-tab --layout git --cwd "$dir" --name "$tab_name"
    else
      ( builtin cd -- "$dir" && zellij -n git )
    fi
  }

  # `fif <pattern> [rg-args]` — interactive ripgrep | fzf content search with
  # bat preview. Selecting a match opens the file at the matched line: in the
  # current coding tab's nvim pane when its socket is reachable (same hash
  # logic as the `coding` launcher), otherwise in a new nvim in this pane.
  fif() {
    if [[ $# -eq 0 ]]; then
      print -u2 "usage: fif <pattern> [rg-args...]"; return 1
    fi
    local result
    result=$(
      rg --color=always --line-number --no-heading --smart-case -- "$@" |
        fzf --ansi \
            --delimiter ':' \
            --preview 'bat --color=always --highlight-line {2} -- {1}' \
            --preview-window 'right:60%,+{2}+3/3,border-left'
    ) || return
    local clean file rest line abs
    clean=$(printf '%s' "$result" | sed 's/\x1b\[[0-9;]*[mGKHF]//g')
    file="''${clean%%:*}"
    rest="''${clean#*:}"
    line="''${rest%%:*}"
    abs=$(realpath -- "$file")
    ${openFileInTab} "$abs" "+$line"
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

      # Open (Enter) creates a new Zellij tab for the picked file, each with its
      # own Neovim instance. block=false keeps yazi running as the sidebar.
      # The prepend rule routes every file through this opener (yazi enters
      # directories itself, so they never reach it). realpath makes the path
      # absolute so open-file-in-tab always gets an unambiguous path.
      opener.edit = [
        {
          run = "${openFileInTab} \"$1\"";
          desc = "Open in new Zellij tab";
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

    # Full-screen lazygit tab, launched by `gitview`. Alt-t still adds a
    # terminal below if needed; lazygit's own bottom panel handles most shell
    # needs (press `e` to open the embedded shell in a lazygit split).
    layouts.git = ''
      layout {
          default_tab_template {
              pane size=1 borderless=true {
                  plugin location="zellij:tab-bar"
              }
              children
              pane size=1 borderless=true {
                  plugin location="file:${pkgs.zellijPlugins.zjstatus}" {
                      format_left   "#[fg=#cba6f7,bold] {session} "
                      format_center ""
                      format_right  "{command_git_branch}{datetime}"

                      command_git_branch {
                          command  "bash"
                          args     "-c" "git -C #{cwd} branch --show-current 2>/dev/null"
                          format   "#[fg=#a6e3a1]  {stdout} "
                          interval "5"
                      }

                      datetime {
                          format   "#[fg=#6c7086,italic] %H:%M "
                          timezone "Europe/Paris"
                      }
                  }
              }
          }
          tab name="git" focus=true {
              pane name="lazygit" focus=true {
                  command "${lazygitBin}"
              }
          }
      }
    '';

    # IDE workspace launched by the `coding` shell function:
    #
    #   ┌ files ┐┌──────── editor (nvim) ────────┐
    #   │ yazi  ││                               │
    #   │       │├────────── terminal ───────────┤
    #   └───────┘└───────────────────────────────┘
    #
    # yazi is the file manager in the left pane. Enter on a file calls
    # open-file-in-tab which opens a NEW Zellij tab for that file; Zellij's
    # tab bar serves as the "open files" list instead of bufferline inside Neovim.
    # The right pane hosts Neovim for quick in-workspace edits, and a shell strip
    # beneath it. Alt-t stacks more terminals onto it VSCode-style (see keybinds).
    layouts.coding = ''
      layout {
          default_tab_template {
              pane size=1 borderless=true {
                  plugin location="zellij:tab-bar"
              }
              children
              pane size=1 borderless=true {
                  plugin location="file:${pkgs.zellijPlugins.zjstatus}" {
                      format_left   "#[fg=#cba6f7,bold] {session} "
                      format_center ""
                      format_right  "{command_git_branch}{datetime}"

                      command_git_branch {
                          command  "bash"
                          args     "-c" "git -C #{cwd} branch --show-current 2>/dev/null"
                          format   "#[fg=#a6e3a1]  {stdout} "
                          interval "5"
                      }

                      datetime {
                          format   "#[fg=#6c7086,italic] %H:%M "
                          timezone "Europe/Paris"
                      }
                  }
              }
          }
          tab name="code" focus=true {
              pane split_direction="vertical" {
                  pane size="24%" name="files" focus=true {
                      command "${config.programs.yazi.finalPackage}/bin/yazi"
                  }
                  pane split_direction="horizontal" {
                      pane size="80%" name="editor" {
                          command "${nvimBin}"
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
