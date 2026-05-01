’’’bash

  # eg. for Orbstack
  hm-profile=orbstack

  nix run .#homeConfigurations.$hm-profile.activationPackage \
    --extra-experimental-features nix-command \
    --extra-experimental-features flakes
’’’
