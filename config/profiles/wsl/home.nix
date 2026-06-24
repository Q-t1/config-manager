{ pkgs, inputs, lib, ... }:

{
  imports = [ inputs.zen-browser.homeModules.default ];

  home.packages = with pkgs; [
    skopeo
    jq
    yq
    kubectl
    kubernetes-helm
    openssl
    fluxcd
    claude-code
  ];

  programs.git.settings.user.email = lib.mkForce "quentin.roccia@bleucloud.fr";

  programs.zen-browser = {
    enable = true;
    profiles.default.settings."security.enterprise_roots.enabled" = true;
  };

  programs.zsh.shellAliases.zen = "zen-beta";

  programs.zellij.enable = true;
}
