# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  #Per dominio locale
  networking.extraHosts = ''127.0.0.1 wordpress.local'';

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Rome";

  # Select internationalisation properties.
  i18n.defaultLocale = "it_IT.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "it_IT.UTF-8";
    LC_IDENTIFICATION = "it_IT.UTF-8";
    LC_MEASUREMENT = "it_IT.UTF-8";
    LC_MONETARY = "it_IT.UTF-8";
    LC_NAME = "it_IT.UTF-8";
    LC_NUMERIC = "it_IT.UTF-8";
    LC_PAPER = "it_IT.UTF-8";
    LC_TELEPHONE = "it_IT.UTF-8";
    LC_TIME = "it_IT.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "it";
    xkbVariant = "";
  };

  # Configure console keymap
  console.keyMap = "it2";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.nix = {
    isNormalUser = true;
    description = "nix";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "nix";

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  #Allow Tailscale
  services.tailscale.enable = true;

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    wordpress
    nginx
    certbot
    mariadb
    php
  ];

  # Nginx configuration
  services.nginx = {
    enable = true;
    virtualHosts."wordpress.local" = {
      root = "/var/www/wordpress";
      locations."/" = {
        index = "index.php";
        extraConfig = ''
          try_files $uri $uri/ /index.php?$args;
        '';
      };
      locations."~ \\.php$" = {
        extraConfig = ''
          fastcgi_pass unix:/run/phpfpm/wordpress.sock;
          fastcgi_index index.php;
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        '';
      };
    };
  };

  # PHP-FPM configuration
  services.phpfpm = {
    phpPackage = pkgs.php;
    pools.wordpress = {
      user = "nginx";
      group = "nginx";
      settings = {
        "listen.owner" = "nginx";
        "listen.group" = "nginx";
        "listen.mode" = "0660";
        "pm" = "dynamic";
        "pm.max_children" = 32;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 4;
        "pm.max_requests" = 500;
      };
      phpOptions = ''
        extension=${pkgs.php.extensions.mysqli}/lib/php/extensions/mysqli.so
        extension=${pkgs.php.extensions.pdo_mysql}/lib/php/extensions/pdo_mysql.so
      '';
    };
  };

  # MariaDB configuration
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  # WordPress installation script
  system.activationScripts = {
    installWordPress = ''
      mkdir -p /var/www/wordpress
      rm -rf /var/www/wordpress/*
      cp -r ${pkgs.wordpress}/share/wordpress/* /var/www/wordpress/
      chown -R nginx:nginx /var/www/wordpress
      find /var/www/wordpress -type d -exec chmod 755 {} \;
      find /var/www/wordpress -type f -exec chmod 644 {} \;
    '';
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 80 ];
  networking.firewall.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}