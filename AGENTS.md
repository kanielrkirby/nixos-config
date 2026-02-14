# Agent Guidelines for NixOS Configuration

## General

- Not using Home Manager - all config is in flake.nix directly
- Always prefer flakes/nix-command (enabled in this config) over legacy nix commands

## Git Commits

- Use conventional commits (e.g., `feat:`, `fix:`, `chore:`, `docs:`)
- One-liner messages only, no multi-paragraph explanations
- Atomic commits - self-contained, often revertable, but not always localized; one logical change per commit
- **Never commit without explicit user approval per commit**
- **Never push**

## Rebuilding NixOS

**Always use `nixos-rebuild test` first**, not `switch`. Only use `switch` after the user confirms the test build works.

```bash
sudo nixos-rebuild test   # test first
sudo nixos-rebuild switch # only after user confirms
```

## Updating Dotfiles

The dotfiles flake input is configured to use a local path for development (`path:/home/mx/dev/lab/dotfiles`) but must be switched to GitHub URL for updates.

### Standard Deployment Flow

1. **Copy modified files to dotfiles repo**
   ```bash
   cp /home/mx/.config/bspwm/panel.sh /home/mx/dev/lab/dotfiles/.config/bspwm/panel.sh
   ```

2. **Restore local backups** (if any files were backed up before editing)
   ```bash
   cp /home/mx/.bash_profile.backup /home/mx/.bash_profile
   ```

3. **Commit and push dotfiles changes**
   ```bash
   cd /home/mx/dev/lab/dotfiles
   git add <files>
   git commit -m "feat: description"
   git push
   ```

4. **Switch flake.nix to GitHub URL** (uncomment GitHub, comment local path)
   ```nix
   dotfiles = {
     url = "github:kanielrkirby/dotfiles/main";
     # url = "path:/home/mx/dev/lab/dotfiles";
     flake = false;
   };
   ```

5. **Update flake input**
   ```bash
   nix flake update dotfiles
   ```

6. **Commit and push flake.lock**
   ```bash
   git add flake.lock
   git commit -m "chore: update dotfiles flake input"
   git push
   ```

7. **Restore local path in flake.nix** (comment GitHub, uncomment local path)
   ```nix
   dotfiles = {
     # url = "github:kanielrkirby/dotfiles/main";
     url = "path:/home/mx/dev/lab/dotfiles";
     flake = false;
   };
   ```

8. **Rebuild NixOS**
   ```bash
   sudo nixos-rebuild switch
   ```

**Note**: The local path allows instant testing without commits. GitHub URL is only for official releases.

### Quick Deployment Flow (Single Command)

When you need to deploy quickly without testing, use this one-liner that handles everything:

```bash
cd /home/mx/dev/lab/dotfiles && git add .config/bspwm/panel.py && git commit -m "feat: description" && git push && cd /etc/nixos && sed -i 's|# url = "github:kanielrkirby/dotfiles/main";|url = "github:kanielrkirby/dotfiles/main";|; s|url = "path:/home/mx/dev/lab/dotfiles";|# url = "path:/home/mx/dev/lab/dotfiles";|' flake.nix && nix flake update dotfiles && git add flake.lock && git commit -m "chore: update dotfiles flake input" && git push && sed -i 's|url = "github:kanielrkirby/dotfiles/main";|# url = "github:kanielrkirby/dotfiles/main";|; s|# url = "path:/home/mx/dev/lab/dotfiles";|url = "path:/home/mx/dev/lab/dotfiles";|' flake.nix && rm /home/mx/.config/bspwm/panel.py && sudo nixos-rebuild switch
```

**What it does:**
1. Commits and pushes dotfiles changes
2. Switches flake.nix to GitHub URL
3. Updates flake input
4. Commits and pushes flake.lock
5. Restores local path in flake.nix
6. Removes local file and rebuilds NixOS

## Editing Patched Projects (dwm, st, dwmblocks, etc.)

1. `cd ~/dev/lab/dotfiles/patches/<project>/<project>` (the submodule)
2. `git fetch origin && git checkout <base-commit>` (clean state)
3. `git apply ../01-config.patch` (apply existing patches)
4. Make your changes
5. `git diff > ../01-config.patch` (regenerate patch)
6. `git checkout .` (reset submodule)
7. `cd ~/dev/lab/dotfiles && git add -A && git commit && git push`
8. Update `rev` in `flake.nix` to the new commit hash
9. `nix flake update dotfiles`
10. `sudo nixos-rebuild test`
11. User confirms, then `sudo nixos-rebuild switch`
