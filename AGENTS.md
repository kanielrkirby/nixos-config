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

The flake.nix is committed with **GitHub inputs as default** in the input declarations. For local development, a patch file (`.dev-mode.patch`) switches package derivations to use the **`-dev` versions**. This allows updating from GitHub without manual editing.

### Dev Mode Patch

A `.dev-mode.patch` file contains the changes to use local `-dev` inputs. This patch is:
- Excluded from git (in `.git/info/exclude`)
- Applied during local development
- Removed when updating or committing

**Apply dev mode:**
```bash
cd /etc/nixos
patch -p1 < .dev-mode.patch
```

**Remove dev mode:**
```bash
cd /etc/nixos
git checkout flake.nix  # or: patch -R -p1 < .dev-mode.patch
```

### Updating from GitHub

To pull latest changes from a GitHub repository:

```bash
cd /etc/nixos
git checkout flake.nix           # remove dev mode
nix flake update dotfiles        # or opencode, whispaste, dmente
git add flake.lock
git commit -m "chore: update dotfiles flake input"
patch -p1 < .dev-mode.patch      # reapply dev mode
```

This updates the lockfile for the GitHub input and maintains your local development setup.

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
   git checkout flake.nix
   nix flake update dotfiles
   ```

5. **Commit and push flake.lock**
   ```bash
   git add flake.lock
   git commit -m "chore: update dotfiles flake input"
   git push
   ```

6. **Reapply dev mode and rebuild**
   ```bash
   patch -p1 < .dev-mode.patch
   sudo nixos-rebuild switch
   ```

**Note**: The `-dev` suffix inputs allow instant local testing without commits. GitHub inputs are automatically updated via `nix flake update`.

### Quick Deployment Flow (Single Command)

When you need to deploy quickly without testing, use this one-liner that handles everything:

```bash
cd /home/mx/dev/lab/dotfiles && git add .config/bspwm/panel.py && git commit -m "feat: description" && git push && cd /etc/nixos && git checkout flake.nix && nix flake update dotfiles && git add flake.lock && git commit -m "chore: update dotfiles flake input" && git push && patch -p1 < .dev-mode.patch && rm /home/mx/.config/bspwm/panel.py && sudo nixos-rebuild switch
```

**What it does:**
1. Commits and pushes dotfiles changes
2. Removes dev mode patch
3. Updates flake input from GitHub
4. Commits and pushes flake.lock
5. Reapplies dev mode patch
6. Removes local file and rebuilds NixOS

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
