{ config, pkgs, lib, ... }:

{

  home.sessionVariables = {
    NIX_SSL_CERT_FILE = "${config.home.homeDirectory}/.secrets/bleu-rootca.pem";
  };

  home.activation.importBleuRootCA = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Ensure the directory exists
    mkdir -p $HOME/.pki/nssdb

    # Ensure the database is initialized
    if [ ! -f $HOME/.pki/nssdb/cert9.db ]; then
      ${pkgs.nssTools}/bin/certutil -N -d sql:$HOME/.pki/nssdb --empty-password
    fi

    # Add (or update) the certificate
    ${pkgs.nssTools}/bin/certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "Bleu Root CA" -i ${config.home.homeDirectory}/.secrets/bleu-rootca.pem
  '';

  home.packages = with pkgs; [
    chromium
  ];
}
