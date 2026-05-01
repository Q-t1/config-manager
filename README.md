## How to use it

eg. to use Orbstack profile

~~~
  hm_profile=orbstack
  nix-shell -p git --run 'nix run github:Q-t1/config-manager#homeConfigurations.${hm_profile}.activationPackage --extra-experimental-features nix-command --extra-experimental-features flakes'
~~~
