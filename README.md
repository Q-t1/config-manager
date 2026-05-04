## How to use it

# For NixOS (+ Home-Manager) profiles

~~~
sudo nixos-rebuild switch --flake .#infra-t0
~~~

# For Home-Manager only profiles

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

# Profile matrix

## NixOS Host Profiles

| Host     | System        | Profile  | Home Directory | Kind  |
|----------|---------------|----------|----------------|-------|
| orbstack | aarch64-linux | orbstack | /home/qt1      | home  |
| infra-t0 | x86_64-linux  | infra-t0 | /home/qt1      | nixos |
| infra-t1 | x86_64-linux  | infra-t1 | /home/qt1      | nixos |
| wsl      | x86_64-linux  | wsl      | /home/qt1      | nixos |
