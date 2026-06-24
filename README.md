## How to use it

# For NixOS (+ Home-Manager) profiles

~~~
sudo nixos-rebuild switch --flake .#<profile>
~~~

Example:

~~~
sudo nixos-rebuild switch --flake .#wsl
~~~

# Build flake (Useful for CI)

~~~
nix build --print-out-paths '.#nixosConfigurations.infra-t0.config.system.build.toplevel' \
  --no-link \
  --extra-experimental-features nix-command \
  --extra-experimental-features flakes
~~~

# Profile matrix

| Host     | System        | Kind  | Home Directory |
|----------|---------------|-------|----------------|
| orbstack | aarch64-linux | nixos | /home/qt1      |
| infra-t0 | x86_64-linux  | nixos | /home/qt1      |
| infra-t1 | x86_64-linux  | nixos | /home/qt1      |
| wsl      | x86_64-linux  | nixos | /home/qt1      |
