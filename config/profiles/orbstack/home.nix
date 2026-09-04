{ ... }:

{
  # The `coding` IDE (yazi + zellij + nixvim). OrbStack is a headless Linux
  # container reached over a terminal, so the clipboard rides OSC 52 escapes
  # (the module default) rather than the WSL/Windows bridge.
  imports = [ ../../modules/coding-ide ];
}
