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

## Flake Input Structure

The flake has **dual inputs** for development projects:
- **GitHub inputs** (no suffix): `dotfiles`, `opencode`, `whispaste`, `dmente` - used for production/updates
- **Local dev inputs** (`-dev` suffix): `dotfiles-dev`, `opencode-dev`, `whispaste-dev`, `dmente-dev` - used for local development

The flake.nix is committed with **GitHub inputs as default** in the input declarations, but the actual package derivations use the **`-dev` versions** for local builds. This allows updating from GitHub without commenting/uncommenting.

### Updating from GitHub

To pull latest changes from a GitHub repository:

```bash
nix flake update dotfiles  # or opencode, whispaste, dmente
```

This updates the lockfile for the GitHub input without affecting your local development workflow.

## Updating Dotfiles

The dotfiles are managed via dual inputs. Local development uses `dotfiles-dev`, while GitHub releases use `dotfiles`.

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

4. **Update flake input**
   ```bash
   cd /etc/nixos
   nix flake update dotfiles
   ```

5. **Commit and push flake.lock**
   ```bash
   git add flake.lock
   git commit -m "chore: update dotfiles flake input"
   git push
   ```

6. **Rebuild NixOS**
   ```bash
   sudo nixos-rebuild switch
   ```

**Note**: The `-dev` suffix inputs allow instant local testing without commits. GitHub inputs are automatically updated via `nix flake update`.

### Quick Deployment Flow (Single Command)

When you need to deploy quickly without testing, use this one-liner that handles everything:

```bash
cd /home/mx/dev/lab/dotfiles && git add .config/bspwm/panel.py && git commit -m "feat: description" && git push && cd /etc/nixos && nix flake update dotfiles && git add flake.lock && git commit -m "chore: update dotfiles flake input" && git push && rm /home/mx/.config/bspwm/panel.py && sudo nixos-rebuild switch
```

**What it does:**
1. Commits and pushes dotfiles changes
2. Updates flake input from GitHub
3. Commits and pushes flake.lock
4. Removes local file and rebuilds NixOS

## Editing Patched Projects (dwm, st, dwmblocks, etc.)

1. `cd ~/dev/lab/dotfiles/patches/<project>/<project>` (the submodule)
2. `git fetch origin && git checkout <base-commit>` (clean state)
3. `git apply ../01-config.patch` (apply existing patches)
4. Make your changes
5. `git diff > ../01-config.patch` (regenerate patch)
6. `git checkout .` (reset submodule)
7. `cd ~/dev/lab/dotfiles && git add -A && git commit && git push`
8. `cd /etc/nixos && nix flake update dotfiles`
9. `sudo nixos-rebuild test`
10. User confirms, then `sudo nixos-rebuild switch`
