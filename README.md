## How to use it

eg. to use Orbstack profile

~~~
  
  nix-shell -p git --run 'hm_profile=orbstack && \
  nix run github:Q-t1/config-manager#homeConfigurations.${hm_profile}.activationPackage \
  --extra-experimental-features nix-command \
  --extra-experimental-features flakes \
  --no-write-lock-file'
~~~
