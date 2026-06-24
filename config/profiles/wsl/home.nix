{ pkgs, inputs, lib, config, ... }:

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

  # Certificates.Install policy doesn't persist to the NSS db on Linux;
  # import directly via certutil on every home-manager activation instead.
  home.activation.zenTrustBleuCA = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    zenProfile="${config.xdg.configHome}/zen/default"
    certFile="${./certs/bleu-rootca.pem}"
    if [[ -d "$zenProfile" ]] && [[ -f "$zenProfile/cert9.db" ]]; then
      if ! ${pkgs.nss.tools}/bin/certutil -L -d "$zenProfile" 2>/dev/null | grep -q "bleu.local"; then
        run ${pkgs.nss.tools}/bin/certutil -A \
          -n "bleu.local-SUBCA1-Issuing-CA" \
          -t "CT,C,C" \
          -i "$certFile" \
          -d "$zenProfile"
      fi
    fi
  '';

  programs.zsh.shellAliases.zen = "MOZ_ENABLE_WAYLAND=1 zen-beta &>/dev/null & disown";

  programs.zellij.enable = true;
}
