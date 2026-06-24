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
    policies.Certificates.Install = [ "${./certs/bleu-rootca.pem}" ];
    profiles.default = {
      settings."security.enterprise_roots.enabled" = true;
      search = {
        default = "google";
        force = true;
      };
    };
  };

  programs.zsh.shellAliases.zen = "zen-beta &>/dev/null & disown";

  programs.zellij.enable = true;
}
