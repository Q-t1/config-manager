# Fully declarative Neovim IDE (nixvim), scoped to the WSL profile.
#
# Goal: an IntelliJ-class editor for Nix / JSON / YAML / kustomize / Helm /
# Kubernetes descriptors. Every plugin is pinned by the `nixvim` flake input —
# there is no runtime plugin manager (no lazy.nvim, no Mason). All language
# servers, formatters and linters are provided from nixpkgs on Neovim's PATH,
# which is the only thing that works reliably on NixOS.
{ inputs, pkgs, lib, ... }:

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

    # WSLg exposes a Wayland display, so wl-copy/wl-paste bridge Neovim's yank
    # register straight to the Windows clipboard (mouse-select included).
    clipboard = {
      register = "unnamedplus";
      providers.wl-copy.enable = true;
    };

    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    opts = {
      number = true;
      relativenumber = true;

      # Full mouse support: resize/scroll/select/click across every mode.
      # Windows Terminal already passes mouse events through by default.
      mouse = "a";

      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      softtabstop = 2;
      smartindent = true;

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

    colorschemes.tokyonight = {
      enable = true;
      settings.style = "night";
    };

    plugins = {
      # ---- UI / look & feel -------------------------------------------------
      web-devicons.enable = true; # needs a Nerd Font in the terminal
      lualine.enable = true;
      bufferline.enable = true;
      which-key.enable = true;
      indent-blankline.enable = true;
      todo-comments.enable = true;
      fidget.enable = true; # LSP progress spinner

      # ---- Navigation -------------------------------------------------------
      neo-tree.enable = true; # file explorer (IntelliJ's project tree)
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

          # JSON / JSONC (with SchemaStore catalog)
          jsonls.enable = true;

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
    # completion/hover for chart values. nixvim has no dedicated helm_ls option,
    # so register it directly against lspconfig.
    extraPlugins = [ pkgs.vimPlugins.vim-helm ];

    extraConfigLua = ''
      require("lspconfig").helm_ls.setup({
        settings = {
          ["helm-ls"] = {
            yamlls = { path = "yaml-language-server" },
          },
        },
      })
    '';

    # Formatters / linters / kube tooling that must be on Neovim's PATH.
    # (LSP server binaries are added automatically by the server options above.)
    extraPackages = with pkgs; [
      nixfmt-rfc-style
      prettierd
      stylua
      shfmt
      yamllint
      helm-ls
      kubeconform
      kustomize
    ];

    # Convenience keymaps that mirror the LazyVim defaults.
    keymaps = [
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<cr>";
        options.desc = "Explorer (neo-tree)";
      }
      {
        mode = "n";
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle<cr>";
        options.desc = "Diagnostics (Trouble)";
      }
      {
        mode = "n";
        key = "<leader>cf";
        action.__raw = ''function() require("conform").format({ async = true, lsp_format = "fallback" }) end'';
        options.desc = "Format buffer";
      }
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
        key = "<leader>bd";
        action = "<cmd>bdelete<cr>";
        options.desc = "Delete buffer";
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
