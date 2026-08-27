{ pkgs, lib, config, ... }:

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

    # `coding [target]` opens the Neovim IDE. With no argument or a directory it
    # roots the session there (so the file tree, LSP and telescope all use that
    # project); with a file it just edits it. The subshell keeps the caller's
    # own working directory unchanged.
    coding() {
      local target="''${1:-.}"
      if [[ -d "$target" ]]; then
        ( builtin cd -- "$target" && exec nvim )
      else
        nvim -- "$target"
      fi
    }
  '';

  programs.zellij.enable = true;
}
