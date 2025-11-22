# firejail.nix
{ config, pkgs, lib, ... }:
  
{
  # For more information see https://nixos.wiki/wiki/Firejail
  programs.firejail = {
    enable = true;
    wrappedBinaries = {

      brave = {
        executable = "${pkgs.brave}/bin/brave";
        profile = "${pkgs.firejail}/etc/firejail/brave.profile";
      };

      # kitty = {
      #   executable = "${pkgs.kitty}/bin/kitty";
      #   profile = ../../config/firejail/kitty.profile;
      # };
      
      code = {
        executable = "${pkgs.vscode}/bin/code";
        profile = "${pkgs.firejail}/etc/firejail/code.profile";
      };

      vesktop = {
        executable = "${pkgs.vesktop}/bin/vesktop";
        profile = "${pkgs.firejail}/etc/firejail/vesktop.profile";
      };
      
      firefox = {
        executable = "${pkgs.firefox}/bin/firefox";
        profile = "${pkgs.firejail}/etc/firejail/firefox.profile";

      };
    };
  };  
}
