# NixOS Configuration Flake

Everything from git repos. Just two repos needed.

## Git Repo Structure

### 1. Suckless Repo (`github:kanielrkirby/suckless`)

One repo with subdirectories for each program:

```
suckless/
├── dwm/
│   ├── config.h
│   ├── dwm.c
│   └── Makefile
├── dwl/
│   ├── config.h
│   ├── dwl.c
│   └── Makefile
├── st/
│   ├── config.h
│   ├── st.c
│   └── Makefile
├── dwmblocks/
│   └── ...
└── someblocks/
    └── ...
```

### 2. Dotfiles Repo (`github:kanielrkirby/dotfiles`)

Structured for GNU Stow:

```
dotfiles/
├── .bashrc
├── .gitconfig
├── .tmux.conf
├── .config/
│   ├── helix/
│   ├── qutebrowser/
│   ├── yazi/
│   └── gh/
└── .local/
    └── bin/
        └── menu_custom
```

## Installation

### 1. Update flake.nix

Edit lines 9-15:

```nix
dotfiles.url = "github:YOUR_USERNAME/dotfiles";
suckless.url = "github:YOUR_USERNAME/suckless";
```

### 2. Deploy

```bash
# Copy flake to VM
scp ~/nixos-setup/flake.nix user@vm:~/nixos-setup/

# In VM:
cd ~/nixos-setup
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
sudo ln -s ~/nixos-setup /etc/nixos
sudo nixos-rebuild switch --flake .#nixos
```

## Updates

```bash
# Update all repos
nix flake update

# Rebuild
sudo nixos-rebuild switch --flake .#nixos
```

## Benefits

✅ **Two repos:** One for suckless software, one for dotfiles  
✅ **Zero local state:** Everything from git  
✅ **Subdirectories:** All suckless programs in one repo  
✅ **Auto-stow:** Dotfiles deployed on every rebuild  
✅ **Atomic updates:** `nix flake update` updates everything  

This would have prevented your Qt6/libxkbcommon issue entirely!
