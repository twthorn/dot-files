# dot-files

Personal shell configuration for macOS and Linux.

## Quick Start

```bash
git clone git@github.com:twthorn/dot-files.git
cd dot-files
./setup.sh
cp .bashrc_private.example ~/.bashrc_private
# Edit ~/.bashrc_private — set WORK_EMAIL and host aliases
source ~/.bashrc
```

Re-run `setup.sh` any time you pull changes — it's idempotent and will only apply what's needed.

## What's Included

| File | Purpose |
|---|---|
| `.bashrc` | Shell config, PATH, aliases, Vitess env vars |
| `.bash_prompt` | Custom bash prompt |
| `.vimrc` | Vim config with plugins (vim-plug) |
| `.tmux.conf` | Tmux config with session save/restore (resurrect + continuum) |
| `.ideavimrc` | JetBrains IDE vim keybindings |
| `.gitconfig` | Git config with `include`/`includeIf` for email routing |
| `.gitignore_global` | Global git ignore patterns |
| `.git_template/` | Git hooks for ctags |

## Private Config

All machine-specific and work-specific config lives in one file: `~/.bashrc_private`. This file is sourced by `.bashrc` and is not tracked in git. See `.bashrc_private.example` for the template.

It stores:
- `GIT_EMAIL` — default (personal) git email for all repos
- `WORK_EMAIL` — work git email, auto-generates `~/.gitconfig-work`
- `WORK_GIT_DIRS` — array of directories where work email applies (sets up git `includeIf` entries)
- `REMOTE_SERVER` — for the `git_interceptor` function
- SSH host aliases, any other private config

Repos under directories listed in `WORK_GIT_DIRS` automatically use your work email. All other directories use your default (personal) email. Nothing work-specific is committed to git.

After running `setup.sh`:

```bash
cp .bashrc_private.example ~/.bashrc_private
# Edit ~/.bashrc_private — set WORK_EMAIL and host aliases
source ~/.bashrc
```

Verify it's working:

```bash
cd ~/git/your-work-org/any-repo
git config user.email   # should show your work email
```

## Helper Scripts

These live in `scripts/` and are called by `setup.sh` — you shouldn't need to run them directly:

| Script | Purpose |
|---|---|
| `scripts/install_dependencies.sh` | Installs packages via Homebrew/apt/dnf/yum/pacman + TPM |
| `scripts/reload_all.sh` | Reloads `.bashrc` and `.tmux.conf` across all tmux sessions |
| `scripts/tmux_shell.sh` | Tmux shell wrapper that bypasses readonly TMOUT idle timeout |
| `scripts/migrate_host.sh` | Migrates home directory to a new remote dev host |
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
cp .bashrc_private.example ~/.bashrc_private
# Edit ~/.bashrc_private — set WORK_EMAIL and host aliases
source ~/.bashrc
```

## Migrating to a New Remote Dev Host

When you get a new dev box (or move from one to another), this gets you back to a working state with all repos, tmux sessions, and config intact.

### 1. Copy data and run setup

```bash
scripts/migrate_host.sh new-host-name
```

This handles everything: rsyncs your entire home directory to the new host, pulls the latest dot-files, and runs setup.sh. It shows rsync progress in real-time.

To migrate between two remote hosts (e.g., old kube box to new one):

```bash
scripts/migrate_host.sh new-host old-host
```

### 2. Restore tmux sessions

The tmux resurrect plugin saves session state to `~/.tmux/resurrect/`. If you rsync'd that directory, your sessions are recoverable:

```bash
# Start tmux
tmux

# Check which backup will be used
trestore --dry-run

# Point resurrect at the best backup
trestore

# Then restore inside tmux: prefix (Ctrl-Space), then Ctrl-r
```

This restores all session names, window layouts, pane directories, and running commands.

### 3. Verify

```bash
# Git email is correct for work repos
cd ~/git/work-org/any-repo && git config user.email

# TMOUT is not set (sessions won't be killed)
echo $TMOUT    # should be empty

# Tmux sessions are restored
tmux ls
```

### Tips

- Update `~/.bashrc_private` on the new host if the alias for the old host needs to change
- If git repos need re-authentication, ensure your credential helper or SSH keys are set up
- The `sync-to` function in `.bashrc` can keep your local and remote repos in sync going forward
