## How to use it

eg. to use Orbstack profile

~~~
  hm-profile=orbstack
  nix shell nixpkgs#git --command \
    nix run github:Q-t1/config-manager#homeConfigurations.${hm_profile}.activationPackage \
      --extra-experimental-features nix-command \
      --extra-experimental-features flakes
~~~
