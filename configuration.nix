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
  networking.extraHosts = ''
    127.0.0.1 wordpress.local
  '';

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
    openssl
    gnused
    curl
  ];

  # Nginx configuration
  services.nginx = {
    enable = true;
    user = "nginx";
    group = "nginx";
    virtualHosts."wordpress.local" = {
      root = "/var/www/wordpress";
      locations."~ \.php$".extraConfig = ''
        fastcgi_pass unix:${config.services.phpfpm.pools.wordpress.socket};
        fastcgi_index index.php;
      '';
      locations."/".index = "index.php index.html index.htm";
      extraConfig = ''
        location = /favicon.ico {
          log_not_found off;
          access_log off;
        }
        location = /robots.txt {
          allow all;
          log_not_found off;
          access_log off;
        }
        location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
          expires max;
          log_not_found off;
        }
      '';
    };
  };

  # PHP-FPM configuration
  services.phpfpm.pools.wordpress = {
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
  };

  # MariaDB configuration
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };
  
  system.activationScripts.wordpressSetup = ''
    # Verifica se l'utente del database esiste già
  USER_EXISTS=$(${pkgs.mariadb}/bin/mysql -s -N -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = 'wordpress' AND host = 'localhost')")
  if [ "$USER_EXISTS" = "1" ]; then
    echo "DB USER ALREADY EXIST!! STOPPING BULDING.."
    exit 1
  fi
    mkdir -p /var/www/wordpress
    cp -r ${pkgs.wordpress}/share/wordpress/* /var/www/wordpress/
    chown -R nginx:nginx /var/www/wordpress

    # Generazione password casuale per l'utente MySQL
    DB_PASSWORD=$(${pkgs.openssl}/bin/openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
    ${pkgs.mariadb}/bin/mysql -e "CREATE DATABASE IF NOT EXISTS wordpress1;"
    ${pkgs.mariadb}/bin/mysql -e "CREATE USER IF NOT EXISTS 'wordpress'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
    ${pkgs.mariadb}/bin/mysql -e "GRANT ALL PRIVILEGES ON wordpress1.* TO 'wordpress'@'localhost';"
    ${pkgs.mariadb}/bin/mysql -e "FLUSH PRIVILEGES;"

    # Configurazione di wp-config.php
    cp /var/www/wordpress/wp-config-sample.php /var/www/wordpress/wp-config.php
    ${pkgs.gnused}/bin/sed -i "s/database_name_here/wordpress1/" /var/www/wordpress/wp-config.php
    ${pkgs.gnused}/bin/sed -i "s/username_here/wordpress/" /var/www/wordpress/wp-config.php
    ${pkgs.gnused}/bin/sed -i "s/password_here/$DB_PASSWORD/" /var/www/wordpress/wp-config.php
    ${pkgs.gnused}/bin/sed -i "s/localhost/localhost/" /var/www/wordpress/wp-config.php

    #  # Generazione delle chiavi di sicurezza
    #   KEYS=$(${pkgs.curl}/bin/curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    #   ${pkgs.gnused}/bin/sed -i "/put your unique phrase here/d" /var/www/wordpress/wp-config.php
    #   echo "$KEYS" >> /var/www/wordpress/wp-config.php

    #  FS_METHOD
    echo "define('FS_METHOD', 'direct');" >> /var/www/wordpress/wp-config.php

   chown -R nginx:nginx /var/www/wordpress
   chmod -R 755 /var/www/wordpress

  '';

 # Create PHP-FPM socket directory with correct permissions
  system.activationScripts.phpfpmSocketDir = {
    text = ''
      mkdir -p /run/phpfpm
      chown nginx:nginx /run/phpfpm
      chmod 755 /run/phpfpm
    '';
    deps = [];
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
