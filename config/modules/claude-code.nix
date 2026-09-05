# `claude` CLI sourced from github:sadjow/claude-code-nix rather than nixpkgs:
# that flake republishes upstream releases hourly, where the nixpkgs package
# trails them by weeks. The overlay simply replaces `pkgs.claude-code`, so
# every call site (wsl's home.packages, the coding-ide neovim wrapper) keeps
# referring to it by that name. Still unfree, so importing profiles keep
# `nixpkgs.config.allowUnfree = true`.
{ inputs, ... }:

{
  nixpkgs.overlays = [ inputs.claude-code.overlays.default ];

  # Prebuilt binaries for the above; without it each new release is rebuilt
  # locally on every host.
  nix.settings = {
    substituters = [ "https://claude-code.cachix.org" ];
    trusted-public-keys = [
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
    ];
  };
}
