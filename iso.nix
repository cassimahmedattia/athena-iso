{ pkgs, modulesPath, lib, ... }: {
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
    "${modulesPath}/profiles/all-hardware.nix"
    "${modulesPath}/profiles/base.nix"
    "${modulesPath}/profiles/installation-device.nix"

    # Enable devices which are usually scanned, because we don't know the
    # target system.
    "${modulesPath}/installer/scan/detected.nix"
    "${modulesPath}/installer/scan/not-detected.nix"

    # Allow "nixos-rebuild" to work properly by providing
    # /etc/nixos/configuration.nix.
    "${modulesPath}/profiles/clone-config.nix"

    # Include a copy of Nixpkgs so that nixos-install works out of
    # the box.
    "${modulesPath}/installer/cd-dvd/channel.nix"
  ];

  ############ START profiles/installation-device.nix ############

  config = {
    system.nixos.variant_id = lib.mkDefault "installer";

    # Enable in installer, even if the minimal profile disables it.
    documentation.enable = mkImageMediaOverride true;

    # Show the manual.
    documentation.nixos.enable = mkImageMediaOverride true;

    # Use less privileged athena user
    users.users.athena = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "video" ];
      # Allow the graphical user to login without password
      initialHashedPassword = "";
    };

    # Allow the user to log in as root without a password.
    users.users.root.initialHashedPassword = "";

    # Allow passwordless sudo from athena user
    security.sudo = {
      enable = mkDefault true;
      wheelNeedsPassword = mkImageMediaOverride false;
    };

    # Automatically log in at the virtual consoles.
    services.getty.autologinUser = "athena";

    # Some more help text.
    services.getty.helpLine = ''
      The "athena" and "root" accounts have empty passwords.

      To log in over ssh you must set a password for either "athena" or "root"
      with `passwd` (prefix with `sudo` for "root"), or add your public key to
      /home/athena/.ssh/authorized_keys or /root/.ssh/authorized_keys.

      If you need a wireless connection, type
      `sudo systemctl start wpa_supplicant` and configure a
      network using `wpa_cli`. See the NixOS manual for details.
    '' + optionalString config.services.xserver.enable ''

      Type `sudo systemctl start display-manager' to
      start the graphical user interface.
    '';

    # We run sshd by default. Login is only possible after adding a
    # password via "passwd" or by adding a ssh key to ~/.ssh/authorized_keys.
    # The latter one is particular useful if keys are manually added to
    # installation device for head-less systems i.e. arm boards by manually
    # mounting the storage in a different system.
    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };

    # Enable wpa_supplicant, but don't start it by default.
    networking.wireless.enable = mkDefault true;
    networking.wireless.userControlled.enable = true;
    systemd.services.wpa_supplicant.wantedBy = mkOverride 50 [];

    # Tell the Nix evaluator to garbage collect more aggressively.
    # This is desirable in memory-constrained environments that don't
    # (yet) have swap set up.
    environment.variables.GC_INITIAL_HEAP_SIZE = "1M";

    # Make the installer more likely to succeed in low memory
    # environments.  The kernel's overcommit heustistics bite us
    # fairly often, preventing processes such as nix-worker or
    # download-using-manifests.pl from forking even if there is
    # plenty of free memory.
    boot.kernel.sysctl."vm.overcommit_memory" = "1";

    # To speed up installation a little bit, include the complete
    # stdenv in the Nix store on the CD.
    system.extraDependencies = with pkgs;
      [
        stdenv
        stdenvNoCC # for runCommand
        busybox
        jq # for closureInfo
        # For boot.initrd.systemd
        makeInitrdNGTool
      ];

    boot.swraid.enable = true;

    # Show all debug messages from the kernel but don't log refused packets
    # because we have the firewall enabled. This makes installs from the
    # console less cumbersome if the machine has a public IP.
    networking.firewall.logRefusedConnections = mkDefault false;

    # Prevent installation media from evacuating persistent storage, as their
    # var directory is not persistent and it would thus result in deletion of
    # those entries.
    environment.etc."systemd/pstore.conf".text = ''
      [PStore]
      Unlink=no
    '';

    # allow nix-copy to live system
    nix.settings.trusted-users = [ "root" "athena" ];
  };

  ############ END profiles/installation-device.nix ############

  ############ START installer/cd-dvd/installation-cd-base.nix ############

  # Adds terminus_font for people with HiDPI displays
  console.packages = options.console.packages.default ++ [ pkgs.terminus_font ];

  # ISO naming.
  isoImage.isoName = "${config.isoImage.isoBaseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";

  # EFI booting
  isoImage.makeEfiBootable = true;

  # USB booting
  isoImage.makeUsbBootable = true;

  # Add Memtest86+ to the CD.
  boot.loader.grub.memtest86.enable = true;

  # An installation media cannot tolerate a host config defined file
  # system layout on a fresh machine, before it has been formatted.
  swapDevices = mkImageMediaOverride [ ];
  fileSystems = mkImageMediaOverride config.lib.isoFileSystems;

  boot.postBootCommands = ''
    for o in $(</proc/cmdline); do
      case "$o" in
        live.athena.passwd=*)
          set -- $(IFS==; echo $o)
          echo "athena:$2" | ${pkgs.shadow}/bin/chpasswd
          ;;
      esac
    done
  '';

  system.stateVersion = lib.mkDefault lib.trivial.release;

  ############ END installer/cd-dvd/installation-cd-base.nix ############

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
    getty.autologinUser = "athena";

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
      displayManager.startx.enable = true;
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
     #microcodeAmd ./hardware/cpu/amd-microcode.nix
     #btrfs-progs ./tasks/filesystems/btrfs.nix
     #dhcpcd ./services/networking/dhcpcd.nix
     dialog
     dosfstools
     edk2-uefi-shell
     #efibootmgr profiles/base.nix
     #grub2 ./system/boot/loader/grub/grub.nix
     inetutils
     #microcodeIntel ./hardware/cpu/intel-microcode.nix
     #linux-firmware ./hardware/all-firmware.nix
     #lvm2 ./tasks/lvm.nix
     #mesa ./hardware/opengl.nix
     mkinitcpio-nfs-utils
     #mtools profiles/base.nix
     #nano ./programs/nano.nix
     nettools
     #networkmanager ./services/networking/networkmanager.nix
     networkmanagerapplet
     #nfs-utils ./tasks/filesystems/nfs.nix
     #nssmdns ./config/nsswitch.nix
     #ntfs3g tasks/filesystems/ntfs.nix
     ##ntp ./services/networking/ntp/ntpd.nix
     #os-prober ./system/boot/loader/grub/grub.nix
     pavucontrol
     #pipewire ./services/desktops/pipewire/pipewire.nix
     pv
     #rsync ./services/network-filesystems/rsyncd.nix
     #sof-firmware ./hardware/all-firmware.nix
     #squashfs-tools-ng ./tasks/filesystems/squashfs.nix
     #sudo ./security/sudo.nix
     #testdisk profiles/base.nix
     #usbutils profiles/base.nix
     wirelesstools
     #wireplumber ./services/desktops/pipewire/wireplumber.nix
     #wpa_supplicant ./services/networking/wpa_supplicant.nix
     #xfsprogs ./tasks/filesystems/xfs.nix
     #noto-fonts ./config/fonts/packages.nix has noto-fonts-color-emoji
     #noto-fonts-emoji ./config/fonts/packages.nix has noto-fonts-color-emoji
     bat
     espeakup
     #git ./programs/git.nix
     gparted
     lsd
     netcat-openbsd
     orca
     #polkit ./security/polkit.nix
     #vnstat ./services/monitoring/vnstat.nix
     wget
     which
     xclip
     zoxide
  ];
}
