{
  description = "NixOS configuration for mx";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    # Your dotfiles repo (stow-managed)
    dotfiles = {
      url = "github:kanielrkirby/dotfiles";
      flake = false;
    };

    # Your suckless software repo (with subdirs for each program)
    suckless = {
      url = "github:kanielrkirby/suckless";  # One repo with dwm/, dwl/, st/, etc subdirs
      flake = false;
    };
  };

  outputs = { self, nixpkgs, dotfiles, suckless, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      
      _dwm = import ./derivations/dwm.nix { inherit pkgs suckless; };
      
      _st = import ./derivations/st.nix { inherit pkgs suckless; };
      
      _dwl = import ./derivations/dwl.nix { inherit pkgs suckless; };
      
      _dwmblocks = import ./derivations/dwmblocks.nix { inherit pkgs suckless; };
      
      _dwlblocks = import ./derivations/dwlblocks.nix { inherit pkgs suckless; };
      
      _dwlb = import ./derivations/dwlb.nix { inherit pkgs suckless; };
      
      # Custom menu script from dotfiles repo
      _menu_custom = pkgs.writeShellScriptBin "menu_custom" (
        builtins.replaceStrings 
          ["ente-otp-manager" "wifimenu \"--$MENU_CMD\""] 
          ["enteauth" "networkmanager_dmenu"] 
          (builtins.readFile "${dotfiles}/.local/bin/menu_custom")
      );
      
      # Shared configuration module
      baseConfig = { config, pkgs, lib, ... }: {
            # Allow unfree packages
            nixpkgs.config.allowUnfree = true;
            
            # Apply overlays
            nixpkgs.overlays = [
              (final: prev: {
                bitwarden-menu = prev.bitwarden-menu.overrideAttrs (oldAttrs: {
                  postPatch = (oldAttrs.postPatch or "") + ''
                    # Fix KeyError when folderId is missing (only reads, not assignments)
                    sed -i "s/\(\['\|, \)\(['a-z]*\)\['folderId'\]/\1\2.get('folderId')/g" bwm/bwview.py
                  '';
                });
                # Wrap ente-auth with software rendering for AMD Strix GPU compatibility
                ente-auth = prev.ente-auth.overrideAttrs (oldAttrs: {
                  postFixup = (oldAttrs.postFixup or "") + ''
                    wrapProgram $out/bin/enteauth \
                      --set LIBGL_ALWAYS_SOFTWARE 1
                  '';
                });
              })
            ];

            boot.loader = {
              systemd-boot.enable = true;
              efi.canTouchEfiVariables = true;
              grub.enable = false;
            };

            boot.zfs.extraPools = [ "zpool" ];

            fileSystems = {
              "/" = {
                device = "zpool/root";
                fsType = "zfs";
              };
              "/nix" = {
                device = "zpool/nix";
                fsType = "zfs";
              };
              "/var" = {
                device = "zpool/var";
                fsType = "zfs";
              };
              "/home" = {
                device = "zpool/home";
                fsType = "zfs";
              };
              "/boot" = {
                device = "/dev/nvme0n1p1";
                fsType = "vfat";
              };
            };

            swapDevices = [
              {
                device = "/dev/nvme0n1p3";
              }
            ];

            # Networking
            networking.hostName = "nixos";
            networking.networkmanager.enable = true;
            networking.hostId = "1f80dbe2";

            # Time zone
            time.timeZone = "America/New_York";

            # Locale
            i18n.defaultLocale = "en_US.UTF-8";

            services.dbus.enable = true;

            # X11 Configuration
            services.xserver = {
              enable = true;
              autorun = false;
              
              displayManager.startx.enable = true;
              displayManager.startx.generateScript = true;
              displayManager.startx.extraCommands = ''
                ${_dwmblocks}/bin/dwmblocks &
              '';
              
              windowManager.dwm = {
                enable = true;
                package = _dwm;
              };
              
              xkb.layout = "us";
            };

            # Wayland compositors
            programs.hyprland.enable = false;  # Set to true if you want Hyprland
            
            # Custom Wayland session for dwl
            environment.etc."wayland-sessions/dwl.desktop".text = ''
              [Desktop Entry]
              Name=dwl
              Comment=dwl - dwm for Wayland
              Exec=${_dwl}/bin/dwl
              Type=Application
            '';

            # AMD GPU
            hardware.graphics.enable = true;
            hardware.graphics.enable32Bit = true;
            hardware.graphics.extraPackages = with pkgs; [
              vulkan-loader
            ];

            # Keyring for secrets (needed by ente-auth, bitwarden, etc)
            services.gnome.gnome-keyring.enable = true;
            security.pam.services.login.enableGnomeKeyring = true;
            security.pam.services.passwd.enableGnomeKeyring = true;
            security.pam.services.greetd.enableGnomeKeyring = true;
            
            # GPG with dmenu pinentry
            programs.gnupg.agent = {
              enable = true;
              pinentryPackage = pkgs.pinentry-dmenu;
            };

            # Sound
            security.rtkit.enable = true;
            services.pipewire = {
              enable = true;
              alsa.enable = true;
              alsa.support32Bit = true;
              pulse.enable = true;
              wireplumber.enable = true;
            };

            # Docker
            virtualisation.docker.enable = true;

            # Libvirt
            virtualisation.libvirtd.enable = true;

            # Mullvad VPN
            services.mullvad-vpn.enable = true;

            # TLP for power management
            services.tlp.enable = true;

            # Users
            users.users.mx = {
              isNormalUser = true;
              description = "mx";
              extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" ];
              initialPassword = "changeme";
            };
            programs.git = {
              enable = true;
              config = {
                init = {
                  defaultBranch = "main";
                };
                user.email = "piratey7007+1923@runbox.com";
                user.name = "kanielrkirby";
              };
            };
            
            # Bash configuration with zoxide
            programs.bash = {
              interactiveShellInit = ''
                eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
              '';
            };

             # System packages
             environment.systemPackages = with pkgs; [
               # Suckless software (custom builds)
               _dwm
               _dwl
               _st
               _dwmblocks
               _dwlblocks
               _dwlb
               _menu_custom
              
              # Menu and tools
              dmenu
              wmenu
              foot
              bitwarden-menu
              bitwarden-cli
              networkmanager_dmenu
              ente-auth
              ente-cli
              libsecret
              pinentry-dmenu
              gcr
              
              # Browsers
              qutebrowser
              vivaldi
              firefox
              
              # Communication
              signal-desktop
              
              # Development
              git-lfs
              helix
              vim
              gh
              clang
              docker
              
              # Terminal tools
              yazi
              tmux
              bash-completion
              btop
              tealdeer
              trash-cli
              zoxide
              fzf
              eza
              httpie
              
              # System utilities
              brightnessctl
              wireplumber  # for wpctl
              mullvad-vpn
              stow  # For dotfiles management
              
              # Clipboard
              xclip
              wl-clipboard
              
              # File manager
              xfce.thunar
              
              # Media
              mpv
              
              # Notifications
              dunst  # X11
              # tiramisu  # Wayland alternative
              
              # SSH
              openssh
              
              # Uutils coreutils replacements
              uutils-coreutils-noprefix
              
              # LF file manager
              lf

              opencode
              
              # sxhkd (commented out for now)
              # sxhkd
            ];

            # Deploy dotfiles from git repo using activation script
            system.activationScripts.dotfiles = ''
              # Symlink dotfiles repo to user home for stow
              if [ ! -L /home/mx/.dotfiles ]; then
                ln -sfn ${dotfiles} /home/mx/.dotfiles
                chown -h mx:users /home/mx/.dotfiles
              fi
              
              # Run stow as user (exclude qutebrowser, it needs writable config)
              ${pkgs.su}/bin/su - mx -c "cd /home/mx/.dotfiles && ${pkgs.stow}/bin/stow -t /home/mx --restow --ignore='\.config/qutebrowser' ."
              
              # Copy qutebrowser config (don't overwrite if exists)
              if [ ! -d /home/mx/.config/qutebrowser ]; then
                mkdir -p /home/mx/.config
                cp -r --no-preserve=mode ${dotfiles}/.config/qutebrowser /home/mx/.config/
                chown -R mx:users /home/mx/.config/qutebrowser
                chmod -R u+w /home/mx/.config/qutebrowser
              fi
            '';

            # Default applications
            xdg.mime.defaultApplications = {
              "text/html" = "org.qutebrowser.qutebrowser.desktop";
              "x-scheme-handler/http" = "org.qutebrowser.qutebrowser.desktop";
              "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
            };

            # Font configuration
            fonts.packages = with pkgs; [
              dejavu_fonts
              noto-fonts
              noto-fonts-color-emoji
            ];

            # Enable flakes
            nix.settings.experimental-features = [ "nix-command" "flakes" ];

            # System state version
            system.stateVersion = "24.11";
      };
      
    in {
      # Main system configuration (EFI)
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hardware-configuration.nix
          baseConfig
          { nixpkgs.config.allowUnfree = true; }
        ];
      };
      
      # VM configuration (GRUB)
      nixosConfigurations.nixos-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          /etc/nixos/hardware-configuration.nix
          baseConfig
          { nixpkgs.config.allowUnfree = true; }
          ({ lib, ... }: {
            # Override bootloader for VM
            boot.loader.systemd-boot.enable = lib.mkForce false;
            boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
            boot.loader.grub.enable = true;
            boot.loader.grub.device = "/dev/vda";
          })
        ];
      };
      
      # ISO installer configuration
      nixosConfigurations.nixos-iso = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          baseConfig
          { nixpkgs.config.allowUnfree = true; }
          ({ config, pkgs, lib, ... }: {
            
            # Override some settings for ISO
            isoImage.squashfsCompression = "zstd";
            
            # Don't require hardware-configuration.nix for ISO
            boot.loader.systemd-boot.enable = lib.mkForce false;
            boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
            
            # Disable activation scripts that depend on /home/mx existing
            system.activationScripts.dotfiles = lib.mkForce "";
          })
        ];
      };
      
      # Development shell for testing
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          git
          stow
          gnumake
          gcc
        ];
      };
    };
}
