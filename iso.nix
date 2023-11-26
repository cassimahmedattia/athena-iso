{ pkgs, modulesPath, lib, ... }: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-base.nix"
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_zen;
    kernelModules = [ "rtl8821cu" ];
  };

  # Needed for https://github.com/NixOS/nixpkgs/issues/58959
  boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "ext4" "f2fs" "xfs" "ntfs" "cifs" ];

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    opengl = {
      enable = true;
    };
  };

  services = {
    # Autologin by startx
    getty.autologinUser = "nixos";

    timesyncd = {
      # feel free to change to sth around your location
      # servers = ["pl.pool.ntp.org"];
      enable = true;
    };

    printing.enable = true;
    vnstat.enable = true;

    xserver = {
      enable = true;
      autorun = false;
      layout = "us";
      xkbVariant = "";
      libinput.enable = true;
      desktopManager = {
        xfce.enable = true;
        xfce.enableXfwm = true;
      };
      displayManager.defaultSession = "xfce";
      #displayManager.startx.enable = true;
    };

    pipewire = {
      enable = true;
      pulse.enable = true;
    };

    avahi = {
      enable = true;
      browseDomains = [];
      wideArea = false;
      nssmdns = true;
    };

    unbound = {
      enable = true;
      settings.server = {
        access-control = [];
        interface = [];
      };
    };
    
    # using VPN is generally a good idea
    # use Mullvad btw
    # mullvad-vpn.enable = true;

    hardware = {
      bolt.enable = true;
    };

    spice-vdagentd.enable = true;
    qemuGuest.enable = true;
  };

  programs.xfconf.enable = true;

  #virtualisation.docker.enable = true;

  virtualisation.vmware.guest.enable = true;
  virtualisation.hypervGuest.enable = true;
  virtualisation.virtualbox.guest.enable = false;

  networking = {
    hostName = "AthenaOS";
    #proxy = {
    #  # default = "http://user:password@proxy:port/";
    #  # noProxy = "127.0.0.1,localhost,internal.domain";
    #};
    wireless.enable = lib.mkForce false;
    networkmanager.enable = true;
    firewall = {
      #allowedTCPPorts = [22 80];
      #allowPing = false;
      checkReversePath = "loose";
      enable = true;
      logReversePathDrops = true;
      # trustedInterfaces = [ "" ];
    };
  };

  security = {
    # if you want, you can disable sudo and use doas
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
      execWheelOnly = true;
    };
    # apparmor.enable = true;
    # lockKernelModules = true;
    auditd.enable = true;
    audit = {
      enable = true;
      rules = ["-a exit, always -F arch=b64 -s execve"];
    };
  };

  #time.timeZone = "UTC"; # change to your one

  # locales as well
  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  # default user config
  users.users.athena = {
    isNormalUser = true;
    home = "/home/athena";
    description = "Athena";
    initialPassword = "athena";
    extraGroups = [
      "wheel"
      "rfkill"
      "sys"
      "lp"
      "input"
    ];
  };

  # nix config
  nix = {
    package = pkgs.nixUnstable;
    settings = {
      extra-experimental-features = [
        "nix-command"
        "flakes"
      ];
      allowed-users = ["@wheel"]; #locks down access to nix-daemon
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
     microcodeAmd
     btrfs-progs
     dhcpcd
     dialog
     dosfstools
     edk2-uefi-shell
     efibootmgr
     grub2
     inetutils
     microcodeIntel
     linux-firmware
     lvm2
     mesa
     mkinitcpio-nfs-utils
     mtools
     nano
     nettools
     networkmanager
     networkmanagerapplet
     nfs-utils
     nssmdns
     ntfs3g
     #ntp
     os-prober
     pavucontrol
     #pipewire
     pv
     rsync
     sof-firmware
     squashfs-tools-ng
     #sudo
     testdisk
     usbutils
     wirelesstools
     wireplumber
     wpa_supplicant
     xfsprogs
     noto-fonts
     noto-fonts-emoji
     bat
     espeakup
     git
     gparted
     lsd
     netcat-openbsd
     orca
     polkit
     vnstat
     wget
     which
     xclip
     zoxide
  ];
}
