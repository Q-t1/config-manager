## How to use it

# For NixOS (+ Home-Manager) profiles

~~~
sudo nixos-rebuild switch --flake .#infra-t0
~~~

# For Home-Manager profile only

~~~
hm_profile=orbstack
nix run .#homeConfigurations.${hm_profile}.activationPackage \
  --extra-experimental-features nix-command \
  --extra-experimental-features flakes
~~~

# Build flake (Useful for CI)

~~~
nix build --print-out-paths '€#nixosConfigurations.infra-t0.config.system.build.toplevel' \
  --no-link \
  --extra-experimental-features nix-command \
  --extra-experimental-features flakes
~~~
