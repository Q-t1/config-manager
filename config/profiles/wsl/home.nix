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

  programs.zsh.shellAliases.zen = "MOZ_ENABLE_WAYLAND=1 zen-beta &>/dev/null & disown";

  programs.zellij.enable = true;
}
