# dot-files

Personal shell configuration for macOS and Linux.

## Quick Start

```bash
git clone git@github.com:twthorn/dot-files.git
cd dot-files
./setup.sh
```

That's it. `setup.sh` is the only command you need to run. It handles everything:

- Installs dependencies (Homebrew packages, TPM, tmux plugins)
- Copies dot files to `$HOME`
- Configures git (ctags integration)
- Sets default shell to bash
- Configures keyboard repeat settings (macOS)
- Installs iTerm2 dark profile (macOS)
- Reloads `.bashrc` and `.tmux.conf` in all running tmux sessions

Re-run `setup.sh` any time you pull changes — it's idempotent and will only apply what's needed.

## What's Included

| File | Purpose |
|---|---|
| `.bashrc` | Shell config, PATH, aliases, Vitess env vars |
| `.bash_prompt` | Custom bash prompt |
| `.vimrc` | Vim config with plugins (vim-plug) |
| `.tmux.conf` | Tmux config with session save/restore (resurrect + continuum) |
| `.ideavimrc` | JetBrains IDE vim keybindings |
| `.gitignore_global` | Global git ignore patterns |
| `.git_template/` | Git hooks for ctags |

## Private Config

Machine-specific aliases (SSH hosts, etc.) go in `~/.bashrc_private` — this file is sourced by `.bashrc` if it exists but is not tracked in git. See `.bashrc_private.example` for the template.

## Helper Scripts

These live in `scripts/` and are called by `setup.sh` — you shouldn't need to run them directly:

| Script | Purpose |
|---|---|
| `scripts/install_dependencies.sh` | Installs packages via Homebrew/apt/dnf/yum/pacman + TPM |
| `scripts/reload_all.sh` | Reloads `.bashrc` and `.tmux.conf` across all tmux sessions |
| `scripts/migrate_cursor.sh` | Migrates Cursor IDE chat history when moving to a new Mac |
| `scripts/restore_tmux.sh` | Smart tmux restore — picks best backup (alias: `trestore`) |

## Migrating to a New Mac

### Cursor IDE

Cursor settings, keybindings, extensions, and chat history are all stored in one directory. To migrate:

1. On the old Mac, AirDrop or copy `~/Library/Application Support/Cursor` to the new Mac (same path)
2. If workspace chat history isn't showing up (workspaces get new hashes on a new machine), run:
   ```bash
   scripts/migrate_cursor.sh --dry-run   # preview what will be migrated
   scripts/migrate_cursor.sh             # apply the migration
   ```
   Cursor must be closed during migration.

### Everything Else

```bash
git clone git@github.com:twthorn/dot-files.git
cd dot-files
./setup.sh
```

Then add any private config (SSH aliases, etc.) to `~/.bashrc_private`.
