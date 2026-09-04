# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Nix flake managing NixOS system configurations and Home Manager user configurations across multiple machines. All hosts share `config/common/home.nix` as a base; each host extends it with a profile-specific `home.nix`.

## Commands

Apply a profile (NixOS):
```
sudo nixos-rebuild switch --flake .#<profile>
```

Format Nix files:
```
nix fmt
```

Build a profile without activating (useful for CI / syntax checks):
```
nix build --print-out-paths '.#nixosConfigurations.<profile>.config.system.build.toplevel' \
  --no-link \
  --extra-experimental-features nix-command \
  --extra-experimental-features flakes
```

## Architecture

### Profile auto-discovery

`flake.nix` reads every subdirectory of `config/profiles/` and imports its `host.nix`. That file declares two fields:

```nix
{ system = "x86_64-linux"; kind = "nixos"; }
```

- `kind = "nixos"` → entry goes into `nixosConfigurations`, combining `configuration.nix` + Home Manager inline
- `kind = "home"` → entry goes into `homeConfigurations` (standalone Home Manager only)

Adding a new host requires only a new directory with `host.nix`, `configuration.nix`, and `home.nix` — no edits to `flake.nix`.

### Layer order (NixOS hosts)

1. `config/modules/nix-settings.nix` — always applied globally (enables flakes/nix-command)
2. `config/profiles/<profile>/configuration.nix` — system-level config; imports hardware, modules, etc.
3. `config/common/home.nix` — shared Home Manager base (zsh, git, neovim, zed, nil/nixd LSPs)
4. `config/profiles/<profile>/home.nix` — profile-specific Home Manager additions

### Reusable modules (`config/modules/`)

Standalone NixOS modules imported explicitly by profiles that need them:
- `boot-efi.nix` — EFI boot loader
- `locale-fr.nix` — French locale
- `openssh.nix` — SSH daemon
- `user-qt1-server.nix` — user account setup for server hosts
- `nix-settings.nix` — experimental features (always applied via `flake.nix`)

One directory here is a **Home Manager** module, imported from a profile's
`home.nix` rather than its `configuration.nix`:
- `coding-ide/` — the `coding` IDE (yazi + zellij + nixvim). `default.nix` is
  the yazi/zellij workspace, `nvim.nix` the editor. Exposes one option,
  `programs.codingIde.clipboardProvider` (`wsl` | `osc52` | `none`), so each
  profile picks how the clipboard is reached. Imported by wsl (`wsl`) and
  orbstack (`osc52`). Pulls the unfree `claude-code`, so an importing profile
  needs `nixpkgs.config.allowUnfree = true`.

### Profile matrix

| Profile  | System        | Kind  | Notes                                      |
|----------|---------------|-------|--------------------------------------------|
| wsl      | x86_64-linux  | nixos | WSL2, Docker, Zen Browser, bleu rootCA     |
| orbstack | aarch64-linux | nixos | LXC container inside OrbStack on macOS; coding-ide |
| infra-t0 | x86_64-linux  | nixos | Bare-metal server, static IP 192.168.1.230 |
| infra-t1 | x86_64-linux  | nixos | Bare-metal server                          |

### Special args available in all modules

- `inputs` — flake inputs (use for `inputs.zen-browser.homeModules.default`, etc.)
- `username` — `"qt1"`
- `profile` — the profile name string
- `system` — the system string (e.g. `"x86_64-linux"`)
