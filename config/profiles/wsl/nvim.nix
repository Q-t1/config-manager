# Fully declarative Neovim IDE (nixvim), scoped to the WSL profile.
#
# Goal: an IntelliJ-class editor for Nix / JSON / YAML / kustomize / Helm /
# Kubernetes descriptors. Every plugin is pinned by the `nixvim` flake input —
# there is no runtime plugin manager (no lazy.nvim, no Mason). All language
# servers, formatters and linters are provided from nixpkgs on Neovim's PATH,
# which is the only thing that works reliably on NixOS.
{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  # vscode-langservers-extracted 4.10.0 ships a broken JSON server bundle: it
  # mixes CommonJS `require()` with a lone `import.meta.url`, so Node 24 can run
  # it as neither (as ESM `require` is undefined; as CJS `import.meta` is a
  # syntax error) and jsonls crashes at startup. Pin the bundle to CommonJS and
  # rewrite that one ESM-ism to its CJS equivalent.
  jsonlsFixed = pkgs.vscode-langservers-extracted.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      srv="$out/lib/node_modules/vscode-langservers-extracted/lib/json-language-server/node"
      echo '{ "type": "commonjs" }' > "$srv/package.json"
      substituteInPlace "$srv/jsonServerMain.js" \
        --replace-fail 'import.meta.url' "require('url').pathToFileURL(__filename).href"
    '';
  });
in
{
  imports = [ inputs.nixvim.homeModules.nixvim ];

  # The shared base (config/common/home.nix) enables programs.neovim, which also
  # wants to own ~/.config/nvim. nixvim manages that directory itself, so turn
  # the plain neovim module off here to avoid a collision.
  programs.neovim.enable = lib.mkForce false;

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Nixvim builds its plugins from this nixpkgs. Pin it explicitly to our
    # (followed) nixpkgs so nixvim stops warning that the input `follows`
    # diverges from its own tested pin.
    nixpkgs.source = inputs.nixpkgs;

    # WSLg exposes a Wayland display, so wl-copy/wl-paste bridge Neovim's yank
    # register straight to the Windows clipboard (mouse-select included).
    clipboard = {
      register = "unnamedplus";
      providers.wl-copy.enable = true;
    };

    globals = {
      mapleader = " ";
      maplocalleader = " ";

      # vim-visual-multi: bind VSCode's Ctrl-d ("select next occurrence") and
      # Ctrl-shift-l ("select all occurrences") to the multi-cursor engine.
      VM_maps = {
        "Find Under" = "<C-d>";
        "Find Subword Under" = "<C-d>";
        "Select All" = "<C-S-l>";
      };
      VM_show_warnings = 0;

      # neo-tree owns the file tree; disable netrw so `nvim <dir>` doesn't race
      # it (on 0.12 `gx` uses vim.ui.open, not netrw, so nothing is lost).
      loaded_netrw = 1;
      loaded_netrwPlugin = 1;
    };

    opts = {
      number = true;
      relativenumber = false; # VSCode shows absolute line numbers

      # Full mouse support: resize/scroll/select/click across every mode.
      # Windows Terminal already passes mouse events through by default.
      mouse = "a";

      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      softtabstop = 2;
      smartindent = true;

      background = "dark";
      termguicolors = true;
      signcolumn = "yes";
      cursorline = true;
      scrolloff = 4;
      wrap = false;

      ignorecase = true;
      smartcase = true;

      undofile = true;
      splitright = true;
      splitbelow = true;

      updatetime = 200;
      timeoutlen = 300;
    };

    # VSCode Dark+ theme (Mofiqul/vscode.nvim).
    colorschemes.vscode = {
      enable = true;
      settings.italic_comments = true;
    };

    plugins = {
      # ---- UI / look & feel -------------------------------------------------
      web-devicons.enable = true; # needs a Nerd Font in the terminal
      which-key.enable = true;
      indent-blankline.enable = true;
      todo-comments.enable = true;
      fidget.enable = true; # LSP progress spinner
      barbecue.enable = true; # VSCode-style breadcrumb bar (winbar)
      navic.enable = true; # symbol context feeding the breadcrumbs
      notify.enable = true; # VSCode-style toast notifications
      rainbow-delimiters.enable = true; # bracket-pair colorization

      lualine = {
        enable = true;
        settings.options.theme = "auto"; # follow the vscode colorscheme
      };

      # Editor tabs styled like VSCode: per-tab LSP diagnostics + an EXPLORER
      # gutter so the tab bar lines up beside the neo-tree sidebar.
      bufferline = {
        enable = true;
        settings.options = {
          diagnostics = "nvim_lsp";
          offsets = [
            {
              filetype = "neo-tree";
              text = "EXPLORER";
              separator = true;
              text_align = "left";
            }
          ];
        };
      };

      # ---- Navigation -------------------------------------------------------
      # VSCode-style file explorer / project tree; hijack netrw so `nvim .`
      # (the `coding` alias) opens straight into the tree.
      neo-tree = {
        enable = true;
        settings = {
          close_if_last_window = true;
          window = {
            position = "left";
            width = 34;
          };
          filesystem = {
            hijack_netrw_behavior = "disabled";
            follow_current_file.enabled = true;
            use_libuv_file_watcher = true;
          };
        };
      };
      telescope = {
        enable = true;
        extensions.fzf-native.enable = true;
        keymaps = {
          "<leader><space>" = "find_files";
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
          "<leader>fd" = "diagnostics";
          "<leader>fs" = "lsp_document_symbols";
        };
      };

      # ---- Editing ----------------------------------------------------------
      nvim-autopairs.enable = true;
      nvim-surround.enable = true;
      comment.enable = true;

      # Integrated terminal panel at the bottom (VSCode's Ctrl-` panel).
      toggleterm = {
        enable = true;
        settings = {
          direction = "horizontal";
          size = 14;
        };
      };

      # ---- Git --------------------------------------------------------------
      gitsigns.enable = true;

      # ---- Syntax / structure ----------------------------------------------
      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
      };
      treesitter-context.enable = true;

      # ---- Diagnostics ------------------------------------------------------
      trouble.enable = true;

      # ---- Completion -------------------------------------------------------
      luasnip.enable = true;
      friendly-snippets.enable = true;
      blink-cmp = {
        enable = true;
        settings = {
          keymap.preset = "default";
          sources.default = [
            "lsp"
            "path"
            "snippets"
            "buffer"
          ];
          completion.documentation.auto_show = true;
          signature.enabled = true;
        };
      };

      # ---- LSP --------------------------------------------------------------
      lsp = {
        enable = true;
        servers = {
          # Nix
          nixd.enable = true;

          # YAML — schema-aware validation for Kubernetes / kustomize manifests.
          # keyOrdering=false stops it from demanding alphabetical keys, and the
          # bundled SchemaStore gives kube/CRD/CI completion out of the box.
          yamlls = {
            enable = true;
            settings.yaml = {
              keyOrdering = false;
              validate = true;
              format.enable = false; # prettier owns formatting (see conform)
              schemaStore.enable = true;
            };
          };

          # JSON / JSONC (with SchemaStore catalog). The stock server package
          # crashes under Node, so use the patched build (see jsonlsFixed).
          jsonls = {
            enable = true;
            package = jsonlsFixed;
          };

          # Lua (for editing this very config)
          lua_ls.enable = true;

          # Shell
          bashls.enable = true;
        };
        keymaps = {
          lspBuf = {
            "gd" = "definition";
            "gD" = "declaration";
            "gr" = "references";
            "gi" = "implementation";
            "gy" = "type_definition";
            "K" = "hover";
            "<leader>cr" = "rename";
            "<leader>ca" = "code_action";
          };
          diagnostic = {
            "]d" = "goto_next";
            "[d" = "goto_prev";
            "<leader>cd" = "open_float";
          };
        };
      };

      # ---- Formatting (format-on-save) -------------------------------------
      conform-nvim = {
        enable = true;
        settings = {
          formatters_by_ft = {
            nix = [ "nixfmt" ];
            yaml = [ "prettierd" ];
            json = [ "prettierd" ];
            jsonc = [ "prettierd" ];
            markdown = [ "prettierd" ];
            lua = [ "stylua" ];
            sh = [ "shfmt" ];
          };
          format_on_save = {
            lsp_format = "fallback";
            timeout_ms = 1500;
          };
        };
      };

      # ---- Linting ----------------------------------------------------------
      lint = {
        enable = true;
        lintersByFt = {
          yaml = [ "yamllint" ];
        };
      };
    };

    # Helm charts: towolf/vim-helm sets filetype=helm for templates so the YAML
    # server does not choke on Go templating, and helm-ls (wired below) provides
    # completion/hover for chart values.
    extraPlugins = with pkgs.vimPlugins; [
      vim-helm
      vim-visual-multi # VSCode-style multi-cursor (Ctrl-d)
      claudecode-nvim # Claude Code IDE integration (like the VSCode extension)
    ];

    # nixvim has no helm_ls option, so register it with Neovim's built-in LSP
    # API. The older `require('lspconfig').helm_ls.setup()` framework is
    # deprecated on 0.11+; its warning would otherwise pop up as a startup
    # toast now that nvim-notify intercepts vim.notify.
    extraConfigLua = ''
      vim.lsp.config("helm_ls", {
        cmd = { "helm_ls", "serve" },
        filetypes = { "helm" },
        root_markers = { "Chart.yaml" },
        settings = {
          ["helm-ls"] = {
            yamlls = { path = "yaml-language-server" },
          },
        },
      })
      vim.lsp.enable("helm_ls")

      -- Claude Code integration — mirrors the VSCode/JetBrains extension:
      -- shared selection, in-editor diffs, and a `claude` terminal. auto_start
      -- is off so the WebSocket bridge only comes up when you open Claude.
      require("claudecode").setup({
        auto_start = false,
        terminal = {
          provider = "native",
          split_side = "right",
          split_width_percentage = 0.35,
        },
      })

      -- VSCode-style: auto-open the file tree as a left sidebar on launch, for
      -- a bare `nvim` or `nvim <dir>` (the `coding` launcher) — i.e. whenever
      -- you open the IDE on a project. Single-file launches are left alone so
      -- the tree never fights the $EDITOR use cases (git commit, kubectl edit),
      -- and because summoning neo-tree onto an already-loaded file buffer at
      -- startup makes it render as a floating popup; open it there with Ctrl-b.
      vim.api.nvim_create_autocmd("VimEnter", {
        desc = "Open neo-tree as a left sidebar on launch",
        callback = function()
          local argc = vim.fn.argc()
          local opened_dir = argc == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1
          if argc == 0 or opened_dir then
            if opened_dir then
              vim.cmd("enew") -- blank editor in the main window
            end
            vim.cmd("Neotree show left") -- show without stealing focus
          end
        end,
      })
    '';

    # Formatters / linters / kube tooling that must be on Neovim's PATH.
    # (LSP server binaries are added automatically by the server options above.)
    extraPackages = with pkgs; [
      nixfmt
      prettierd
      stylua
      shfmt
      yamllint
      helm-ls
      kubeconform
      kustomize
      claude-code # `claude` CLI used by the claudecode.nvim integration
    ];

    # VSCode-style keybindings.
    #
    # Terminal caveat: Windows Terminal cannot deliver most Ctrl-Shift-<key>
    # chords to a WSL app (no kitty keyboard protocol), so those are marked
    # "best effort" and each has a reliable F-key or <leader> equivalent.
    keymaps = [
      # -- Command palette / quick open --------------------------------------
      {
        mode = "n";
        key = "<F1>";
        action = "<cmd>Telescope commands<cr>";
        options.desc = "Command palette";
      }
      {
        mode = "n";
        key = "<C-p>";
        action = "<cmd>Telescope find_files<cr>";
        options.desc = "Quick open (files)";
      }

      # -- Claude Code -------------------------------------------------------
      {
        mode = "n";
        key = "<leader>ac";
        action = "<cmd>ClaudeCode<cr>";
        options.desc = "Claude Code (toggle)";
      }
      {
        mode = "n";
        key = "<leader>af";
        action = "<cmd>ClaudeCodeFocus<cr>";
        options.desc = "Claude Code (focus)";
      }
      {
        mode = "v";
        key = "<leader>as";
        action = "<cmd>ClaudeCodeSend<cr>";
        options.desc = "Send selection to Claude";
      }
      {
        mode = "n";
        key = "<C-S-p>"; # best effort
        action = "<cmd>Telescope commands<cr>";
        options.desc = "Command palette";
      }
      {
        mode = "n";
        key = "<C-S-f>"; # best effort; also <leader>fg
        action = "<cmd>Telescope live_grep<cr>";
        options.desc = "Search in files";
      }
      {
        mode = "n";
        key = "<C-b>";
        action = "<cmd>Neotree toggle<cr>";
        options.desc = "Toggle sidebar";
      }
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<cr>";
        options.desc = "Explorer (neo-tree)";
      }

      # -- Save / select / clipboard -----------------------------------------
      {
        mode = [
          "n"
          "i"
          "v"
        ];
        key = "<C-s>";
        action = "<Cmd>w<CR>"; # <Cmd> keeps insert/visual mode
        options.desc = "Save file";
      }
      {
        mode = "n";
        key = "<C-a>";
        action = "ggVG";
        options.desc = "Select all";
      }
      {
        mode = "v";
        key = "<C-c>";
        action = "\"+y";
        options.desc = "Copy to system clipboard";
      }
      {
        mode = "v";
        key = "<C-x>";
        action = "\"+d";
        options.desc = "Cut to system clipboard";
      }
      {
        mode = [
          "i"
          "c"
        ];
        key = "<C-v>";
        action = "<C-r>+"; # normal-mode <C-v> stays visual-block
        options.desc = "Paste from system clipboard";
      }

      # -- Comment toggle (Ctrl-/) -------------------------------------------
      {
        mode = "n";
        key = "<C-/>";
        action = "<cmd>lua require('Comment.api').toggle.linewise.current()<cr>";
        options.desc = "Toggle comment";
      }
      {
        mode = "n";
        key = "<C-_>"; # some terminals send Ctrl-/ as Ctrl-_
        action = "<cmd>lua require('Comment.api').toggle.linewise.current()<cr>";
        options.desc = "Toggle comment";
      }
      {
        mode = "v";
        key = "<C-/>";
        action = "<Plug>(comment_toggle_linewise_visual)";
        options = {
          remap = true;
          desc = "Toggle comment";
        };
      }
      {
        mode = "v";
        key = "<C-_>";
        action = "<Plug>(comment_toggle_linewise_visual)";
        options = {
          remap = true;
          desc = "Toggle comment";
        };
      }

      # -- Move / duplicate lines (Alt-Up/Down) ------------------------------
      {
        mode = "n";
        key = "<A-Down>";
        action = "<cmd>m .+1<cr>==";
        options.desc = "Move line down";
      }
      {
        mode = "n";
        key = "<A-Up>";
        action = "<cmd>m .-2<cr>==";
        options.desc = "Move line up";
      }
      {
        mode = "i";
        key = "<A-Down>";
        action = "<esc><cmd>m .+1<cr>==gi";
        options.desc = "Move line down";
      }
      {
        mode = "i";
        key = "<A-Up>";
        action = "<esc><cmd>m .-2<cr>==gi";
        options.desc = "Move line up";
      }
      {
        mode = "v";
        key = "<A-Down>";
        action = ":m '>+1<cr>gv=gv";
        options.desc = "Move selection down";
      }
      {
        mode = "v";
        key = "<A-Up>";
        action = ":m '<-2<cr>gv=gv";
        options.desc = "Move selection up";
      }
      {
        mode = "n";
        key = "<A-S-Down>"; # best effort
        action = "<cmd>t.<cr>";
        options.desc = "Duplicate line down";
      }

      # -- Code navigation (F-keys mirror VSCode) ----------------------------
      {
        mode = "n";
        key = "<F2>";
        action = "<cmd>lua vim.lsp.buf.rename()<cr>";
        options.desc = "Rename symbol";
      }
      {
        mode = "n";
        key = "<F12>";
        action = "<cmd>lua vim.lsp.buf.definition()<cr>";
        options.desc = "Go to definition";
      }
      {
        mode = "n";
        key = "<S-F12>";
        action = "<cmd>Telescope lsp_references<cr>";
        options.desc = "Find references";
      }
      {
        mode = "n";
        key = "<C-.>"; # best effort; also <leader>ca
        action = "<cmd>lua vim.lsp.buf.code_action()<cr>";
        options.desc = "Quick fix / code action";
      }
      {
        mode = "n";
        key = "<F8>";
        action = "<cmd>lua vim.diagnostic.jump({ count = 1, float = true })<cr>";
        options.desc = "Next problem";
      }
      {
        mode = "n";
        key = "<S-F8>";
        action = "<cmd>lua vim.diagnostic.jump({ count = -1, float = true })<cr>";
        options.desc = "Previous problem";
      }
      {
        mode = "n";
        key = "<A-Left>";
        action = "<C-o>";
        options.desc = "Navigate back";
      }
      {
        mode = "n";
        key = "<A-Right>";
        action = "<C-i>";
        options.desc = "Navigate forward";
      }

      # -- Format ------------------------------------------------------------
      {
        mode = "n";
        key = "<A-S-f>"; # best effort; also <leader>cf
        action.__raw = ''function() require("conform").format({ async = true, lsp_format = "fallback" }) end'';
        options.desc = "Format document";
      }
      {
        mode = "n";
        key = "<leader>cf";
        action.__raw = ''function() require("conform").format({ async = true, lsp_format = "fallback" }) end'';
        options.desc = "Format buffer";
      }

      # -- Panels ------------------------------------------------------------
      {
        mode = "n";
        key = "<leader>t";
        action = "<cmd>ToggleTerm<cr>";
        options.desc = "Toggle terminal";
      }
      {
        mode = "t";
        key = "<Esc>";
        action = "<C-\\><C-n>";
        options.desc = "Terminal: exit to normal mode";
      }
      {
        mode = "n";
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle<cr>";
        options.desc = "Problems (Trouble)";
      }

      # -- Buffers / tabs ----------------------------------------------------
      {
        mode = "n";
        key = "<S-h>";
        action = "<cmd>bprevious<cr>";
        options.desc = "Previous buffer";
      }
      {
        mode = "n";
        key = "<S-l>";
        action = "<cmd>bnext<cr>";
        options.desc = "Next buffer";
      }
      {
        mode = "n";
        key = "<C-Tab>"; # best effort
        action = "<cmd>bnext<cr>";
        options.desc = "Next buffer";
      }
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>bdelete<cr>";
        options.desc = "Close buffer";
      }
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<cr>";
        options.desc = "Clear search highlight";
      }
    ];
  };
}
