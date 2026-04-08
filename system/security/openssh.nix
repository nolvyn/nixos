# openssh.nix

{
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PermitRootLogin = "no"; # Must be set to "yes" on target machine for NixOS Anywhere install
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
