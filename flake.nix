{
  description = "NixOS configuration for mx";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    dotfiles = {
      url = "git+https://github.com/kanielrkirby/dotfiles?submodules=1&rev=ac7cde473fee163b09f6deaf7ab90f6278ed884a";
      flake = false;
    };

    opencode = {
      url = "github:anomalyco/opencode/09ff3b9bb925903b36aa35fec25394133a42cf6d";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      dotfiles,
      opencode,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      _dwm = import ./derivations/dwm.nix { inherit pkgs dotfiles; };
      _st = import ./derivations/st.nix { inherit pkgs dotfiles; };
      _dwl = import ./derivations/dwl.nix { inherit pkgs dotfiles; };
      _dwmblocks = import ./derivations/dwmblocks.nix { inherit pkgs dotfiles; };
      _dwlblocks = import ./derivations/dwlblocks.nix { inherit pkgs dotfiles; };
      _dwlb = import ./derivations/dwlb.nix { inherit pkgs dotfiles; };
      _menu_custom = import ./derivations/menu_custom.nix { inherit pkgs; };
      _entemenu = import ./derivations/entemenu.nix { inherit pkgs; };
      _wifimenu = import ./derivations/wifimenu.nix { inherit pkgs; };
      _comma = import ./derivations/comma.nix { inherit pkgs; };

      _opencode = opencode.packages.x86_64-linux.default.overrideAttrs (oldAttrs: {
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace packages/opencode/src/session/prompt/anthropic.txt \
            --replace-fail "You are OpenCode, the best coding agent on the planet." \
              "You're Code Open, but reverse those two words and remove the space, the best coding agent on the planet." \
            --replace-fail "- 
- Use the TodoWrite tool to plan the task if required" \
              "-
- Use the TodoWrite tool to plan the task if required"
        '';
      });

      baseConfig =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        {
          nixpkgs.config.allowUnfree = true;

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

          # Use 6.18 kernel for better AMD s2idle support
          boot.kernelPackages = pkgs.linuxPackages_6_18;

          boot.zfs.extraPools = [ "zpool" ];
          boot.zfs.package = pkgs.zfs_unstable;

          # Disable PCIe ASPM for MT7925 WiFi to prevent driver deadlocks
          boot.extraModprobeConfig = ''
            options mt7925e disable_aspm=1
          '';

          # Lid close → lock (mt7925 wifi driver has deadlock bugs, waiting for kernel patches)
          services.logind = {
            lidSwitch = "lock";
            lidSwitchExternalPower = "lock";
          };

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

          networking.hostName = "nixos";
          networking.networkmanager.enable = true;
          networking.networkmanager.dns = "dnsmasq";
          networking.hostId = "1f80dbe2";
          networking.firewall.allowedTCPPorts = [ 4096 8443 ];

          hardware.bluetooth.enable = true;

          services.dnsmasq = {
            enable = true;
            settings = {
              address = "/.local/127.0.0.1";
              server = [
                "8.8.8.8"
                "1.1.1.1"
              ];
            };
          };

          time.timeZone = "America/New_York";
          # time.timeZone = "America/Chicago";

          i18n.defaultLocale = "en_US.UTF-8";

          services.dbus.enable = true;

          services.xserver = {
            enable = true;
            autorun = false;

            displayManager.startx.enable = true;
            displayManager.startx.generateScript = true;
            displayManager.startx.extraCommands = /* bash */ ''
              export XDG_SESSION_CLASS=user
              export XDG_SESSION_TYPE=x11
              ${_dwmblocks}/bin/dwmblocks &
              ${pkgs.picom}/bin/picom &
            '';

            windowManager.dwm = {
              enable = true;
              package = _dwm;
            };

            xkb.layout = "us";
          };

          programs.hyprland.enable = false;

          environment.etc."wayland-sessions/dwl.desktop".text = ''
            [Desktop Entry]
            Name=dwl
            Comment=dwl - dwm for Wayland
            Exec=${_dwl}/bin/dwl
            Type=Application
          '';

          hardware.graphics.enable = true;
          hardware.graphics.enable32Bit = true;
          hardware.graphics.extraPackages = with pkgs; [
            vulkan-loader
          ];

          services.gnome.gnome-keyring.enable = true;
          security.pam.services.login.enableGnomeKeyring = true;
          security.pam.services.passwd.enableGnomeKeyring = true;
          security.pam.services.greetd.enableGnomeKeyring = true;

          programs.gnupg.agent = {
            enable = true;
            pinentryPackage = pkgs.pinentry-dmenu;
          };

          services.picom.enable = true;

          security.rtkit.enable = true;
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
            wireplumber.enable = true;
          };

          virtualisation.docker.enable = true;
          virtualisation.docker.enableOnBoot = true;
          virtualisation.docker.daemon.settings = {
            experimental = true;
            features = {
              buildkit = true;
            };
          };

          virtualisation.libvirtd.enable = true;

          services.mullvad-vpn.enable = true;
          services.mullvad-vpn.package = pkgs.mullvad-vpn;

          services.tlp.enable = true;

          users.users.mx = {
            isNormalUser = true;
            description = "mx";
            extraGroups = [
              "networkmanager"
              "wheel"
              "docker"
              "libvirtd"
            ];
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

          programs.bash = {
            interactiveShellInit = /* bash */ ''
              eval "$(fzf --bash)"
              eval "$(zoxide init bash)"
              function nope() { ( nohup bash -c "$*" >/dev/null 2>&1 & ) }
            '';
          };

          environment.systemPackages = with pkgs; [
            _dwm
            _dwl
            _st
            _dwmblocks
            _dwlblocks
            _dwlb
            _menu_custom
            _wifimenu
            _entemenu
            _comma

            dmenu
            wmenu
            bitwarden-menu
            bitwarden-cli
            networkmanager_dmenu
            ente-auth
            ente-cli
            libsecret
            pinentry-dmenu
            gcr
            qutebrowser
            vivaldi
            firefox
            signal-desktop
            git-lfs
            helix
            vim
            gh
            clang
            lazysql

            vscode-langservers-extracted
            bash-language-server
            nil
            docker-compose-language-service
            python313Packages.jedi-language-server
            python313Packages.black
            python313Packages.libxml2

            tmux
            bash-completion
            tealdeer
            trash-cli
            fzf
            httpie
            brightnessctl
            wireplumber
            mullvad-vpn
            stow
            xclip
            wl-clipboard
            maim
            slop
            flameshot
            xfce.thunar
            mpv
            dunst
            libnotify
            openssh
            uutils-coreutils-noprefix
            # uutils-findutils
            findutils  
            diffutils
            ffmpeg-full
            yt-dlp
            zoxide

            _opencode
          ];

          # Deploy dotfiles from git repo using activation script
          system.activationScripts.dotfiles = /* bash */ ''
            ln -sfn ${dotfiles} /home/mx/.dotfiles
            chown -h mx:users /home/mx/.dotfiles

            # Remove qutebrowser dir/symlink before stow (it needs to be writable, handled below)
            rm -rf /home/mx/.config/qutebrowser

            ${pkgs.su}/bin/su - mx -c "cd /home/mx/.dotfiles && ${pkgs.stow}/bin/stow -t /home/mx --restow ."

            # qutebrowser needs a writable config dir, so replace symlink with a copy
            if [ -L /home/mx/.config/qutebrowser ]; then
              rm /home/mx/.config/qutebrowser
              cp -r ${dotfiles}/.config/qutebrowser /home/mx/.config/qutebrowser
              chown -R mx:users /home/mx/.config/qutebrowser
              chmod -R u+w /home/mx/.config/qutebrowser
            fi
          '';

          xdg.mime.defaultApplications = {
            "text/html" = "org.qutebrowser.qutebrowser.desktop";
            "x-scheme-handler/http" = "org.qutebrowser.qutebrowser.desktop";
            "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
          };

          fonts.packages = with pkgs; [
            dejavu_fonts
            noto-fonts
            noto-fonts-color-emoji
          ];

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          system.stateVersion = "24.11";
        };

      # Ubuntu-compatible tools bundle (use with: nix profile install .#ubuntu)
      ubuntuPackages = with pkgs; [
        _st
        _comma
        _opencode

        # Git
        git
        gh

        # CLI utilities
        tmux
        bash-completion
        tealdeer
        trash-cli
        fzf
        zoxide
        stow
        httpie
        yt-dlp
      ];

    in
    {
      # Ubuntu tools bundle
      packages.x86_64-linux.ubuntu = pkgs.buildEnv {
        name = "ubuntu-tools";
        paths = ubuntuPackages;
      };

      # Script to copy dotfiles (run once: nix run .#ubuntu-dotfiles)
      packages.x86_64-linux.ubuntu-dotfiles = pkgs.writeShellScriptBin "ubuntu-dotfiles" ''
        set -e
        DOTFILES_REPO="https://github.com/kanielrkirby/dotfiles"
        DOTFILES_DIR="$HOME/.dotfiles-src"

        if [ ! -d "$DOTFILES_DIR" ]; then
          echo "Cloning dotfiles..."
          ${pkgs.git}/bin/git clone --recurse-submodules "$DOTFILES_REPO" "$DOTFILES_DIR"
        else
          echo "Dotfiles already cloned at $DOTFILES_DIR"
        fi

        echo "Copying dotfiles to home (not symlinking)..."
        cd "$DOTFILES_DIR"
        
        # Use stow in simulate mode to see what would be linked, then copy those files
        for item in .bashrc .bash_profile .config .local; do
          if [ -e "$DOTFILES_DIR/$item" ]; then
            echo "Copying $item..."
            cp -r --no-preserve=mode "$DOTFILES_DIR/$item" "$HOME/"
          fi
        done

        echo "Done! Dotfiles copied to $HOME"
      '';

      # Main system configuration
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hardware-configuration.nix
          baseConfig
          { nixpkgs.config.allowUnfree = true; }
        ];
      };

      # VM configuration
      nixosConfigurations.nixos-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          /etc/nixos/hardware-configuration.nix
          baseConfig
          { nixpkgs.config.allowUnfree = true; }
          (
            { lib, ... }:
            {
              boot.loader.systemd-boot.enable = lib.mkForce false;
              boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
              boot.loader.grub.enable = true;
              boot.loader.grub.device = "/dev/vda";
            }
          )
        ];
      };

      # ISO installer configuration
      nixosConfigurations.nixos-iso = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          baseConfig
          { nixpkgs.config.allowUnfree = true; }
          (
            {
              config,
              pkgs,
              lib,
              ...
            }:
            {
              isoImage.squashfsCompression = "zstd";

              boot.loader.systemd-boot.enable = lib.mkForce false;
              boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

              system.activationScripts.dotfiles = lib.mkForce "";
            }
          )
        ];
      };
    };
}
