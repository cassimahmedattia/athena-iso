# This module defines a NixOS installation CD that contains X11 and
# Plasma 5.

{ pkgs, ... }:

{
  imports = [ ./installation-cd-graphical-base.nix ];

  isoImage.edition = "xfce";

  services.xserver = {
    desktopManager = {
      xfce.enable = true;
      xfce.enableXfwm = true;
    };
    displayManager = {
      lightdm.enable = true;
      autoLogin = {
        enable = true;
        user = "athena";
      };
    };
  };

  #environment.systemPackages = with pkgs; [
  #  # Graphical text editor
  #  kate
  #];

}