# Agent Guidelines for NixOS Configuration

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

1. Push changes to GitHub
2. Update the `rev` in `flake.nix` to the new commit hash
3. `nix flake update dotfiles`
4. `sudo nixos-rebuild test`
5. User confirms, then `sudo nixos-rebuild switch`

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
