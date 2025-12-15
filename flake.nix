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
      
      _dwm = pkgs.dwm.overrideAttrs (oldAttrs: {
        src = suckless;
        postUnpack = ''
          sourceRoot="$sourceRoot/dwm"
        '';
        postFixup = ''
          patchelf --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
                   --set-rpath ${pkgs.lib.makeLibraryPath [pkgs.xorg.libX11 pkgs.xorg.libXinerama pkgs.xorg.libXft pkgs.fontconfig pkgs.freetype]} \
                   $out/bin/dwm
        '';
        # Force rebuild
        version = "custom-2";
      });
      
      _st = pkgs.st.overrideAttrs (oldAttrs: {
        src = suckless;
        postUnpack = ''
          sourceRoot="$sourceRoot/st"
        '';
        postFixup = ''
          patchelf --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
                   --set-rpath ${pkgs.lib.makeLibraryPath [pkgs.xorg.libX11 pkgs.xorg.libXft pkgs.fontconfig pkgs.freetype]} \
                   $out/bin/st
        '';
      });
      
      dwl = pkgs.dwl.overrideAttrs (oldAttrs: {
        src = suckless;
        postUnpack = ''
          sourceRoot="$sourceRoot/dwl"
        '';
        # nativeBuildInputs = with pkgs; [ pkg-config wayland-scanner ];
        # buildInputs = with pkgs; [ wayland wayland-protocols libxkbcommon pixman fcft ];
        # preBuild = ''
        #   makeFlagsArray+=(
        #     "PREFIX=$out"
        #     "CC=$CC"
        #     "LDFLAGS=$(${pkgs.stdenv.cc.targetPrefix}pkg-config --static --libs wayland-client wayland-protocols wayland-cursor xkbcommon pixman-1 fcft)"
        #   )
        # '';
      });
      
      dwmblocks = pkgs.stdenv.mkDerivation {
        pname = "dwmblocks";
        version = "custom";
        src = suckless;
        postUnpack = ''
          sourceRoot="$sourceRoot/dwmblocks"
        '';
        buildInputs = with pkgs; [ xorg.libX11 ];
        makeFlags = [ "PREFIX=$(out)" ];
        preBuild = ''
          # Remove dangling symlink if it exists
          rm -f blocks.h
        '';
      };
      
      dwlblocks = pkgs.stdenv.mkDerivation {
        pname = "dwlblocks";
        version = "custom";
        src = suckless;
        postUnpack = ''
          sourceRoot="$sourceRoot/dwlblocks"
        '';
        buildInputs = with pkgs; [ wayland wayland-protocols ];
        makeFlags = [ "PREFIX=$(out)" ];
        preBuild = ''
          # Remove dangling symlink if it exists
          rm -f blocks.h
        '';
      };
      
      dwlb = pkgs.stdenv.mkDerivation {
        pname = "dwlb";
        version = "custom";
        src = suckless;
        postUnpack = ''
          sourceRoot="$sourceRoot/dwlb"
        '';
        nativeBuildInputs = with pkgs; [ pkg-config wayland-scanner ];
        buildInputs = with pkgs; [ wayland wayland-protocols pixman fcft ];
        makeFlags = [ "PREFIX=$(out)" ];
      };
      
      # Custom menu script from dotfiles repo
      menu-custom = pkgs.writeShellScriptBin "menu_custom" ''
        export PATH="${pkgs.dmenu}/bin:${pkgs.bemenu}/bin:$PATH"
        ${builtins.readFile "${dotfiles}/.local/bin/menu_custom"}
      '';
      
      # Shared configuration module
      baseConfig = { config, pkgs, lib, ... }: {
            # Allow unfree packages
            nixpkgs.config.allowUnfree = true;

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

            # X11 Configuration
            services.xserver = {
              enable = true;
              
              # Display manager
              displayManager = {
                lightdm.enable = true;
                defaultSession = "none+dwm";
              };
              
              # Use custom dwm
              windowManager.dwm = {
                enable = true;
                package = _dwm;
              };
              
              # Keyboard
              xkb.layout = "us";
            };

            # Wayland compositors
            programs.hyprland.enable = false;  # Set to true if you want Hyprland
            
            # Custom Wayland session for dwl
            environment.etc."wayland-sessions/dwl.desktop".text = ''
              [Desktop Entry]
              Name=dwl
              Comment=dwl - dwm for Wayland
              Exec=${dwl}/bin/dwl
              Type=Application
            '';

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

            # System packages
            environment.systemPackages = with pkgs; [
              # Suckless software (custom builds)
              _dwm
              dwl
              _st
              dwmblocks
              dwlblocks
              dwlb
              menu-custom
              
              # Menu and tools
              dmenu
              wmenu
              foot
              pkgs.xorg.xinit
              
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
              
              # Run stow as user
              ${pkgs.su}/bin/su - mx -c "cd /home/mx/.dotfiles && ${pkgs.stow}/bin/stow -t /home/mx --restow ."
            '';

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
