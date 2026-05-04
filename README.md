## How to use it

# Home-Manager

eg. to use Orbstack profile

~~~
nix-shell -p git --run 'hm_profile=orbstack && \
nix run github:Q-t1/config-manager#homeConfigurations.${hm_profile}.activationPackage \
  --extra-experimental-features nix-command \
  --extra-experimental-features flakes'
~~~

# System-wide configuration.nix (if applicable)

~~~
sudo nixos-rebuild switch --flake 'github:Q-t1/config-manager#infra-t0'
~~~

# Build flake (Useful for CI)

~~~
nix build --print-out-paths '€#nixosConfigurations.infra-t0.config.system.build.toplevel' \
  --no-link \
  --extra-experimental-features nix-command \
  --extra-experimental-features flakes
~~~
