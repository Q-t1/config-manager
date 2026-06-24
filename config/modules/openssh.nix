{ ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PubkeyAuthentication = "yes";
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
}
