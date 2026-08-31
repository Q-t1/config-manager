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

    # Make "+/"* the default yank/paste registers so plain y/p use the system
    # clipboard. The provider itself (vim.g.clipboard) is defined in
    # extraConfigLua so it can fall back from wl-copy to clip.exe when WSLg's
    # Wayland socket isn't reachable.
    clipboard.register = "unnamedplus";

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

      # yazi is the file manager (its own left zellij pane); disable netrw so
      # `nvim <dir>` doesn't open a directory buffer (on 0.12 `gx` uses
      # vim.ui.open, not netrw, so nothing is lost).
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
      autoread = true; # pick up external edits (Claude, git checkout); see checktime autocmd
      splitright = true;
      splitbelow = true;

      updatetime = 200;
      timeoutlen = 300;
    };

    # Catppuccin Mocha (the dark flavour). Its default integrations already
    # style telescope, bufferline, gitsigns, blink-cmp, trouble,
    # navic/barbecue, notify, indent-blankline, treesitter & which-key, so the
    # whole IDE follows the theme without per-plugin wiring. Catppuccin
    # italicises comments by default (parity with the old vscode theme), and
    # term_colors themes the toggleterm / :terminal palette to match.
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        term_colors = true;
      };
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
        settings.options.theme = "auto"; # follow the active (catppuccin) colorscheme
      };

      # Editor tabs styled like VSCode, with per-tab LSP diagnostics. There is no
      # sidebar offset here: the file manager is yazi, in its own zellij pane
      # outside Neovim rather than a panel inside it.
      bufferline = {
        enable = true;
        settings.options.diagnostics = "nvim_lsp";
      };

      # ---- Navigation -------------------------------------------------------
      # The file manager is yazi, running as its own persistent left zellij pane
      # (see home.nix). It opens files here over a socket, so nothing about the
      # tree lives in this file. Telescope stays for fuzzy find / grep / symbols.
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
          "<leader>fr" = "oldfiles"; # recently opened files (VSCode's recent)
          "<leader>fR" = "resume"; # reopen the last picker with its results
        };
      };

      # ---- Editing ----------------------------------------------------------
      nvim-autopairs.enable = true;
      nvim-surround.enable = true;
      comment.enable = true;

      # Integrated terminal panel at the bottom (VSCode's Ctrl-` panel).
      # Opened with <leader>t (Space t) — Windows Terminal can't deliver
      # Ctrl-` to a WSL app, so the panel is bound to a leader key instead.
      toggleterm = {
        enable = true;
        settings = {
          direction = "horizontal";
          size = 14;
        };
      };

      # ---- Git --------------------------------------------------------------
      # Signs in the gutter, plus buffer-local hunk keymaps wired via on_attach
      # (so they only bind in git-tracked buffers). Uses gitsigns' current
      # nav_hunk API — next_hunk/prev_hunk are @deprecated on 2.x and would emit
      # a toast now that nvim-notify intercepts vim.notify. Full git workflow
      # (stage/commit/branch) is lazygit on <leader>gg (see extraConfigLua).
      gitsigns = {
        enable = true;
        settings.on_attach.__raw = ''
          function(bufnr)
            local gs = require("gitsigns")
            local function map(mode, lhs, rhs, desc)
              vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
            end
            -- Hunk navigation (respect Vim's builtin ]c/[c while in diff mode).
            map("n", "]c", function()
              if vim.wo.diff then vim.cmd.normal({ "]c", bang = true }) else gs.nav_hunk("next") end
            end, "Next hunk")
            map("n", "[c", function()
              if vim.wo.diff then vim.cmd.normal({ "[c", bang = true }) else gs.nav_hunk("prev") end
            end, "Prev hunk")
            -- Stage/reset (stage_hunk toggles staging on 2.x — no separate undo).
            map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
            map("v", "<leader>gs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage selection")
            map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
            map("v", "<leader>gr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset selection")
            map("n", "<leader>gS", gs.stage_buffer, "Stage buffer")
            map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
            map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
            map("n", "<leader>gd", gs.diffthis, "Diff this")
          end
        '';
      };

      # ---- Syntax / structure ----------------------------------------------
      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
      };
      treesitter-context.enable = true;

      # ---- Markdown reading -------------------------------------------------
      # render-markdown.nvim turns a raw `.md` buffer into a formatted document
      # in place — headings get icons/backgrounds, fenced code blocks a filled
      # box with the language name, tables are aligned, bullets/checkboxes/
      # callouts are drawn. It follows catppuccin automatically and drives the
      # `markdown` + `markdown_inline` treesitter parsers (installed with the
      # grammar set above) plus web-devicons (enabled above), so nothing extra
      # is needed. anti_conceal shows the raw source only on the cursor's line,
      # so the file stays fully editable while everything else reads rendered.
      # Toggle raw/rendered on <leader>cm (see keymaps).
      render-markdown = {
        enable = true;
        settings = {
          anti_conceal.enabled = true;
          code = {
            style = "full"; # background box + language label on fenced blocks
            width = "block";
            left_pad = 2;
            right_pad = 2;
          };
          # These are Nix/k8s config docs, not math — skip LaTeX rendering so it
          # never warns about a missing `latex` parser / pylatexenc at :checkhealth.
          latex.enabled = false;
        };
      };

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
      grug-far-nvim # VSCode-style project-wide find & replace (Search panel)
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

      -- The file manager is yazi, running as its own persistent left zellij pane
      -- (see home.nix: the `coding` layout, and the `edit` opener that sends a
      -- picked file here via `nvim --server <sock> --remote`). Neovim just needs
      -- to be reachable on that socket — the `coding` layout launches it with
      -- `--listen`, so there is nothing to wire on this side. Ctrl-h (seamless
      -- nav, below) and <C-b>/<leader>e (keymaps) move focus to that pane.

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

      -- Name the surrounding zellij tab after the project whenever the IDE is
      -- opened on one, so tabs read "config-manager" instead of zellij's
      -- default "Tab #1". Prefer the git repo root's name, falling back to the
      -- directory's. Scoped to the "opened on a project" cases (a bare `nvim` or
      -- `nvim <dir>`) so single-file $EDITOR use (git commit, kubectl edit)
      -- leaves the tab name alone, and a no-op outside zellij. Async so it never
      -- blocks startup.
      vim.api.nvim_create_autocmd("VimEnter", {
        desc = "Name the zellij tab after the project",
        callback = function()
          if vim.env.ZELLIJ == nil then
            return
          end
          local argc = vim.fn.argc()
          local opened_dir = argc == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1
          if argc ~= 0 and not opened_dir then
            return
          end
          local base = opened_dir and vim.fn.fnamemodify(vim.fn.argv(0), ":p") or vim.uv.cwd()
          base = base:gsub("/$", "")
          local root = vim.fs.root(base, ".git")
          local name = vim.fs.basename(root or base)
          if name and name ~= "" then
            vim.system({ "zellij", "action", "rename-tab", name })
          end
        end,
      })

      -- Project-wide find & replace, editable in place (VSCode's Ctrl-Shift-F
      -- Search panel). Opens a buffer listing every match across the project;
      -- edit the "Replace" line and :w / <leader>sr-apply to rewrite all files.
      require("grug-far").setup({})

      -- VSCode-style: a single left click in an editable file drops you
      -- straight into insert ("edit") mode. Guarded to normal file buffers so
      -- it never fires in the terminal or other special windows;
      -- bound in normal mode only so click-drag text selection still works
      -- (a drag ends in visual mode, where this mapping does not apply).
      vim.keymap.set("n", "<LeftRelease>", function()
        if vim.bo.buftype == "" and vim.bo.modifiable and not vim.bo.readonly then
          vim.cmd("startinsert")
        end
      end, { desc = "Click to edit (enter insert mode)" })

      -- VSCode-style: closing your last file leaves an empty editor instead of
      -- quitting Neovim. Plain `:bdelete` can tear the editor window down, so
      -- point every window showing the buffer at a replacement *first* — the
      -- alternate file, else another open file, else a fresh scratch buffer — so
      -- the window always survives the delete. Refuses to discard unsaved
      -- changes, matching plain `:bd`.
      local function close_buffer()
        local bufnr = vim.api.nvim_get_current_buf()
        if vim.bo[bufnr].modified then
          vim.notify(
            "Buffer has unsaved changes — :w to save or :bd! to discard",
            vim.log.levels.WARN
          )
          return
        end
        local alt = vim.fn.bufnr("#")
        local replacement
        if alt ~= bufnr and alt ~= -1 and vim.fn.buflisted(alt) == 1 then
          replacement = alt
        else
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if b ~= bufnr and vim.bo[b].buflisted then
              replacement = b
              break
            end
          end
        end
        replacement = replacement or vim.api.nvim_create_buf(true, false)
        for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
          vim.api.nvim_win_set_buf(win, replacement)
        end
        pcall(vim.api.nvim_buf_delete, bufnr, {})
      end
      vim.keymap.set("n", "<leader>bd", close_buffer, { desc = "Close buffer (keep editor open)" })

      -- WSL clipboard bridge. WSLg's Wayland socket isn't always reachable
      -- (detached shells and some multiplexer contexts return "connection
      -- refused"), which silently breaks yank/paste to the Windows clipboard.
      -- Try the fast native path first (wl-copy / wl-paste) and fall back to
      -- the always-present Windows tools (clip.exe / PowerShell Get-Clipboard).
      local function wsl_copy(lines)
        local text = table.concat(lines, "\n")
        vim.fn.system({ "wl-copy", "--type", "text/plain" }, text)
        if vim.v.shell_error ~= 0 then
          vim.fn.system({ "clip.exe" }, text)
        end
      end
      local function wsl_paste()
        local out = vim.fn.systemlist({ "wl-paste", "--no-newline" })
        if vim.v.shell_error ~= 0 then
          out = vim.fn.systemlist({ "powershell.exe", "-NoProfile", "-Command", "Get-Clipboard" })
          for i, line in ipairs(out) do
            out[i] = (line:gsub("\r$", ""))
          end
          if #out > 0 and out[#out] == "" then
            table.remove(out)
          end
        end
        return out
      end
      vim.g.clipboard = {
        name = "wsl-native-fallback",
        copy = { ["+"] = wsl_copy, ["*"] = wsl_copy },
        paste = { ["+"] = wsl_paste, ["*"] = wsl_paste },
      }

      -- Select-to-copy: releasing a mouse drag-selection yanks it to the system
      -- clipboard, so selecting with the mouse copies like a terminal/VSCode do.
      vim.keymap.set("x", "<LeftRelease>", '"+y', { desc = "Copy mouse selection" })

      -- Seamless window/pane navigation across Neovim splits and zellij panes.
      -- Ctrl-h/j/k/l moves between Neovim splits; at the outermost split it hops
      -- to the adjacent zellij pane instead, so the two read as one continuous
      -- space (the zellij analogue of vim-tmux-navigator). Moving *into* Neovim
      -- from another zellij pane uses zellij's own Alt-h/j/k/l — in a shell pane
      -- Ctrl-h is backspace, so it can't be the universal mover. The zellij keys
      -- that would otherwise shadow these Ctrl chords are freed in home.nix.
      local function zellij_nav(nvim_dir, zellij_dir)
        local before = vim.api.nvim_get_current_win()
        vim.cmd.wincmd(nvim_dir)
        if before == vim.api.nvim_get_current_win() then
          vim.fn.system({ "zellij", "action", "move-focus", zellij_dir })
        end
      end
      for _, m in ipairs({
        { "h", "left" },
        { "j", "down" },
        { "k", "up" },
        { "l", "right" },
      }) do
        vim.keymap.set("n", "<C-" .. m[1] .. ">", function()
          zellij_nav(m[1], m[2])
        end, { desc = "Navigate window/pane " .. m[2] })
      end

      -- Inline diagnostics UX. Neovim's defaults leave virtual text off, so
      -- errors only show in the gutter/float; turn on IntelliJ-style inline
      -- messages, sort by severity so the worst wins a line, and give floats a
      -- border. Nerd Font sign glyphs (the terminal already has one for
      -- web-devicons) replace the default letters.
      vim.diagnostic.config({
        severity_sort = true,
        underline = true,
        update_in_insert = false,
        virtual_text = { spacing = 2, source = "if_many", prefix = "●" },
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.INFO] = "",
            [vim.diagnostic.severity.HINT] = "",
          },
        },
      })

      -- Inlay hints (parameter names, inferred types) — the closest thing to
      -- VSCode/IntelliJ hints. Enabled per-buffer on attach; servers that don't
      -- implement them simply render nothing, so no capability check is needed.
      -- <leader>ch toggles them when they get noisy.
      vim.api.nvim_create_autocmd("LspAttach", {
        desc = "Enable LSP inlay hints",
        callback = function(args)
          if vim.lsp.inlay_hint then
            pcall(vim.lsp.inlay_hint.enable, true, { bufnr = args.buf })
          end
        end,
      })
      vim.keymap.set("n", "<leader>ch", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
      end, { desc = "Toggle inlay hints" })

      -- Reopen a file where you left it. Skip commit/rebase buffers, where the
      -- cursor belongs at the top.
      vim.api.nvim_create_autocmd("BufReadPost", {
        desc = "Restore last cursor position",
        callback = function(args)
          local ft = vim.bo[args.buf].filetype
          if ft == "gitcommit" or ft == "gitrebase" then
            return
          end
          local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
          if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
          end
        end,
      })

      -- autoread only reloads on certain events; nudge it on focus/buffer-enter
      -- so files rewritten underneath the editor (Claude edits, git checkout)
      -- refresh without a manual :e.
      vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave", "BufEnter" }, {
        desc = "Reload buffers changed on disk",
        callback = function()
          if vim.bo.buftype == "" and vim.fn.mode() ~= "c" then
            vim.cmd("checktime")
          end
        end,
      })

      -- Name the which-key <leader> menus so the popup reads as labelled groups
      -- instead of a flat key list.
      require("which-key").add({
        { "<leader>a", group = "AI / Claude" },
        { "<leader>b", group = "Buffer" },
        { "<leader>c", group = "Code" },
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
        { "<leader>s", group = "Search / replace" },
        { "<leader>x", group = "Diagnostics" },
      })

      -- Full git UI (stage/commit/branch/rebase) floated over the editor, the
      -- git-workflow companion to the inline gitsigns hunk keymaps. Reuses the
      -- toggleterm runtime already loaded for the bottom terminal panel.
      local lazygit = require("toggleterm.terminal").Terminal:new({
        cmd = "lazygit",
        direction = "float",
        float_opts = { border = "curved" },
        hidden = true,
      })
      vim.keymap.set("n", "<leader>gg", function()
        lazygit:toggle()
      end, { desc = "Lazygit" })

      -- kubeconform: strict Kubernetes manifest conformance, complementing the
      -- schema validation yamlls already does from SchemaStore. nvim-lint ships
      -- no kubeconform linter, so define one; it reads the buffer on stdin and
      -- reports per-resource schema errors. kubeconform emits no line numbers,
      -- so findings land on line 1 with the offending kind/name/path in the
      -- message (still surfaced through Trouble and virtual text like any
      -- diagnostic).
      require("lint").linters.kubeconform = {
        cmd = "kubeconform",
        stdin = true,
        args = { "-strict", "-ignore-missing-schemas", "-output", "json", "-" },
        ignore_exitcode = true, -- non-zero simply means "found problems"
        parser = function(output, _)
          local diags = {}
          local ok, decoded = pcall(vim.json.decode, output)
          if not ok or type(decoded) ~= "table" or type(decoded.resources) ~= "table" then
            return diags
          end
          for _, res in ipairs(decoded.resources) do
            if res.status == "statusInvalid" or res.status == "statusError" then
              local label = string.format(
                "%s/%s",
                (res.kind ~= nil and res.kind ~= "") and res.kind or "?",
                (res.name ~= nil and res.name ~= "") and res.name or "?"
              )
              local errs = res.validationErrors
              if type(errs) == "table" and #errs > 0 then
                for _, e in ipairs(errs) do
                  table.insert(diags, {
                    lnum = 0,
                    col = 0,
                    severity = vim.diagnostic.severity.ERROR,
                    source = "kubeconform",
                    message = string.format("%s: %s %s", label, e.path or "", e.msg or ""),
                  })
                end
              else
                table.insert(diags, {
                  lnum = 0,
                  col = 0,
                  severity = vim.diagnostic.severity.ERROR,
                  source = "kubeconform",
                  message = string.format("%s: %s", label, res.msg or "invalid"),
                })
              end
            end
          end
          return diags
        end,
      }

      -- Run kubeconform ONLY on buffers that actually look like manifests (a
      -- top-level apiVersion + kind). A blanket lintersByFt entry would flag
      -- every non-k8s YAML (docker-compose, CI configs) with "missing 'kind'
      -- key", so gate it here instead. yamllint still runs on all YAML via the
      -- nixvim lint module's own autocmd; this is an additive namespace.
      local function looks_like_manifest(bufnr)
        local has_api, has_kind = false, false
        for _, l in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 512, false)) do
          if l:match("^apiVersion:%s*%S") then
            has_api = true
          end
          if l:match("^kind:%s*%S") then
            has_kind = true
          end
          if has_api and has_kind then
            return true
          end
        end
        return false
      end
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        desc = "kubeconform: validate Kubernetes manifests",
        callback = function(args)
          if
            vim.bo[args.buf].filetype == "yaml"
            and vim.bo[args.buf].buftype == ""
            and looks_like_manifest(args.buf)
          then
            require("lint").try_lint("kubeconform")
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
      lazygit # full git UI, floated on <leader>gg (see extraConfigLua)
      claude-code # `claude` CLI used by the claudecode.nvim integration
      ripgrep # `rg` backs grug-far's find & replace (and Telescope live_grep)
      wl-clipboard # wl-copy/wl-paste: the fast path for the clipboard bridge
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
        key = "<leader>ab";
        action.__raw = ''function() vim.cmd("ClaudeCodeAdd " .. vim.fn.expand("%:p")) end'';
        options.desc = "Add current file to Claude context";
      }
      {
        mode = "n";
        key = "<leader>aa";
        action = "<cmd>ClaudeCodeDiffAccept<cr>";
        options.desc = "Accept Claude diff";
      }
      {
        mode = "n";
        key = "<leader>ad";
        action = "<cmd>ClaudeCodeDiffDeny<cr>";
        options.desc = "Deny Claude diff";
      }
      {
        mode = "n";
        key = "<C-S-p>"; # best effort
        action = "<cmd>Telescope commands<cr>";
        options.desc = "Command palette";
      }
      # Project-wide find & replace with edit-in-place (VSCode's Ctrl-Shift-F
      # Search panel). Ctrl-Shift-F cannot be delivered to a WSL app, so the
      # reliable entry points are <leader>sr / <leader>sw. (Quick read-only
      # content search is still Telescope live_grep on <leader>fg.)
      {
        mode = "n";
        key = "<C-S-f>"; # best effort; use <leader>sr instead
        action.__raw = ''function() require("grug-far").open() end'';
        options.desc = "Find & replace in files";
      }
      {
        mode = "n";
        key = "<leader>sr";
        action.__raw = ''function() require("grug-far").open() end'';
        options.desc = "Search & replace (project)";
      }
      {
        mode = "v";
        key = "<leader>sr";
        action.__raw = ''function() require("grug-far").with_visual_selection() end'';
        options.desc = "Search & replace selection (project)";
      }
      {
        mode = "n";
        key = "<leader>sw";
        action.__raw = ''function() require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } }) end'';
        options.desc = "Search & replace word under cursor";
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

      # -- Markdown ----------------------------------------------------------
      # Flip the current buffer between the rendered document and the raw
      # markdown source (render-markdown.nvim). Handy when editing tables/links
      # where seeing the literal syntax is easier than the rendered form.
      {
        mode = "n";
        key = "<leader>cm";
        action = "<cmd>RenderMarkdown toggle<cr>";
        options.desc = "Toggle markdown render";
      }

      # -- Panels ------------------------------------------------------------
      # <C-b> / <leader>e move focus to the yazi pane on the left (the file
      # manager is a zellij pane now, not an in-editor panel). This is the same
      # hop as <C-h> at the leftmost split; kept under the familiar VSCode keys
      # for discoverability. A no-op outside zellij.
      {
        mode = "n";
        key = "<C-b>";
        action = "<cmd>lua vim.fn.system({ 'zellij', 'action', 'move-focus', 'left' })<cr>";
        options.desc = "Focus file manager (yazi pane)";
      }
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>lua vim.fn.system({ 'zellij', 'action', 'move-focus', 'left' })<cr>";
        options.desc = "Focus file manager (yazi pane)";
      }
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
      # `<leader>bd` (Close buffer) is defined as a smart function in
      # extraConfigLua so closing your last file never quits Neovim.
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<cr>";
        options.desc = "Clear search highlight";
      }
    ];
  };
}
