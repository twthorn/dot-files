#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Source private config early so vars are available throughout
[[ -f "$HOME/.bashrc_private" ]] && source "$HOME/.bashrc_private"

# Parse flags
RUN_LOCAL=true
RUN_REMOTE=true
SCRIPTS_ONLY=false
case "${1:-}" in
    --local-only)   RUN_REMOTE=false ;;
    --remote-only)  RUN_LOCAL=false ;;
    --scripts-only) SCRIPTS_ONLY=true; RUN_REMOTE=false ;;
esac

# Copy helper scripts to ~/.local/bin. Shared by the full local setup and the
# fast --scripts-only path so both stay in sync.
_copy_scripts() {
    if [[ ! -d "$HOME/.local/bin" ]]; then
        mkdir -p "$HOME/.local/bin" 2>/dev/null || sudo mkdir -p "$HOME/.local/bin" && sudo chown -R "$USER" "$HOME/.local"
    fi
    cp "$SCRIPT_DIR/scripts/restore_tmux.sh" "$HOME/.local/bin/"
    cp "$SCRIPT_DIR/scripts/tmux_shell.sh" "$HOME/.local/bin/"
    cp "$SCRIPT_DIR/scripts/purge_tmux.sh" "$HOME/.local/bin/"
    echo "  Copied helper scripts to ~/.local/bin"
}

# Abort if running with remotes and there are uncommitted changes
if [[ "$RUN_REMOTE" == "true" ]] && [[ -d "$SCRIPT_DIR/.git" ]]; then
    if ! git -C "$SCRIPT_DIR" diff --quiet || ! git -C "$SCRIPT_DIR" diff --cached --quiet; then
        echo "ERROR: Uncommitted changes in dot-files repo."
        echo "Remote hosts will pull stale code. Commit and push first, or use --local-only."
        exit 1
    fi
fi

# --- Local setup ---
_run_local() {

    echo ""
    echo "========================================"
    echo "  HOST: $(hostname)"
    echo "========================================"
    echo ""

    # Install dependencies first
    echo "Installing dependencies..."
    "$SCRIPT_DIR/scripts/install_dependencies.sh"
    echo

    # Copy dot files to home directory
    echo "Copying dot files to $HOME..."
    for f in $(ls -A | egrep '^\.' | grep -v .gitconfig | grep -v ".git$" | grep -v .gitignore | grep -v .claude)
    do
        echo "  cp -r $f $HOME"
        cp -r "$f" "$HOME"
    done
    echo

    # Copy helper scripts to ~/.local/bin
    _copy_scripts

    # Ensure Claude Code permissions (allow everything, deny only external-impact commands)
    mkdir -p "$HOME/.claude"
    if command -v jq >/dev/null 2>&1; then
        TARGET="$HOME/.claude/settings.json"
        [[ ! -f "$TARGET" ]] && echo '{}' > "$TARGET"

        # Build MCP allow rules (e.g. "mcp__slack__*") from every server name found
        # in ~/.mcp_private.json and in any repo's .mcp.json under ~/git. Repos name
        # the same server differently (e.g. "slack" vs "slack-mcp"), so union them all.
        MCP_NAME_FILES=("$HOME/.mcp_private.json")
        while IFS= read -r f; do
            MCP_NAME_FILES+=("$f")
        done < <(find "$HOME/git" -maxdepth 3 -name ".mcp.json" 2>/dev/null)

        MCP_ALLOWS=$(jq -s '[.[].mcpServers // {} | keys[]] | unique | map("mcp__" + . + "__*")' "${MCP_NAME_FILES[@]}" 2>/dev/null)
        [[ -z "$MCP_ALLOWS" ]] && MCP_ALLOWS="[]"

        UPDATED=$(jq --argjson mcp_allows "$MCP_ALLOWS" '.permissions = {
            "allow": (["Bash(*)", "Read(*)", "Edit(*)", "Write(*)", "WebFetch(*)"] + $mcp_allows),
            "deny": ["Bash(rm -rf *)", "Bash(docker rm *)", "Bash(docker rmi *)", "Bash(kubectl delete *)", "Bash(kubectl apply *)", "Bash(kubectl scale *)", "Bash(kubectl rollout *)", "Bash(kubectl exec *)", "Bash(kubectl cordon *)", "Bash(kubectl drain *)", "Bash(knife *)", "Bash(gnife *)", "Bash(helm install *)", "Bash(helm upgrade *)", "Bash(helm uninstall *)", "Bash(terraform apply *)", "Bash(terraform destroy *)"]
        }' "$TARGET")
        echo "$UPDATED" > "$TARGET"
        echo "  Updated Claude Code permissions"

        # Install MCP servers at USER SCOPE so they are available in every repo.
        # Claude Code reads MCP servers ONLY from ~/.claude.json (user/local scope)
        # and per-repo .mcp.json (project scope) -- the mcpServers key in
        # settings.json is ignored. User scope is the base set for every
        # directory; a repo's own .mcp.json layers extra servers on top (union),
        # so we no longer need a session parked in the one repo with the richest
        # .mcp.json. ~/.claude.json is large and stateful, so merge the key in
        # place rather than overwriting the file.
        CLAUDE_JSON="$HOME/.claude.json"
        if [[ -f "$HOME/.mcp_private.json" ]]; then
            [[ ! -f "$CLAUDE_JSON" ]] && echo '{}' > "$CLAUDE_JSON"
            UPDATED=$(jq -s '.[0] * {mcpServers: ((.[0].mcpServers // {}) * (.[1].mcpServers // {}))}' \
                "$CLAUDE_JSON" "$HOME/.mcp_private.json")
            if [[ -n "$UPDATED" ]]; then
                echo "$UPDATED" > "$CLAUDE_JSON"
                echo "  Installed MCP servers at user scope in ~/.claude.json"
            else
                echo "  WARNING: failed to merge MCP servers into ~/.claude.json (left unchanged)"
            fi
        fi
    fi

    # Deploy VS Code / Cursor settings
    if [[ -f "$SCRIPT_DIR/vscode_settings.json" ]]; then
        for EDITOR_DIR in \
            "$HOME/Library/Application Support/Code/User" \
            "$HOME/Library/Application Support/Cursor/User" \
            "$HOME/.config/Code/User" \
            "$HOME/.config/Cursor/User"; do
            if [[ -d "$(dirname "$EDITOR_DIR")" ]]; then
                mkdir -p "$EDITOR_DIR"
                cp "$SCRIPT_DIR/vscode_settings.json" "$EDITOR_DIR/settings.json"
                echo "  Copied editor settings to $EDITOR_DIR"
            fi
        done
    fi

    # Append dot-files CLAUDE.md section (idempotent — replaces previous dot-files block)
    if [[ -f "$SCRIPT_DIR/.claude/CLAUDE.md" ]]; then
        REVIEWERS="${GITHUB_REVIEWERS:-}"
        BLOCK=$(sed "s/%%REVIEWERS%%/$REVIEWERS/" "$SCRIPT_DIR/.claude/CLAUDE.md")
        TARGET="$HOME/.claude/CLAUDE.md"
        MARKER="# --- dot-files managed ---"
        if [[ -f "$TARGET" ]] && grep -qF "$MARKER" "$TARGET"; then
            sed -i.bak "/$MARKER/,\$d" "$TARGET" && rm -f "$TARGET.bak"
        fi
        [[ -f "$TARGET" ]] || touch "$TARGET"
        printf '\n%s\n%s\n' "$MARKER" "$BLOCK" >> "$TARGET"
        echo "  Updated ~/.claude/CLAUDE.md"
    fi

    # Install tmux plugins via TPM (must run after dot files are copied so ~/.tmux.conf is current)
    TPM_DIR="$HOME/.tmux/plugins/tpm"
    mkdir -p "$HOME/.tmux/resurrect"
    if [[ -x "$TPM_DIR/bin/install_plugins" ]]; then
        if tmux list-sessions &>/dev/null; then
            tmux source-file ~/.tmux.conf 2>/dev/null
        fi
        echo "Installing tmux plugins..."
        "$TPM_DIR/bin/install_plugins"
        if tmux list-sessions &>/dev/null; then
            tmux source-file ~/.tmux.conf 2>/dev/null
        fi
        echo
    fi

    # Set up git config
    echo "Setting up git configs..."
    git config --global init.templatedir '~/.git_template'
    git config --global alias.ctags '!.git/hooks/ctags'
    git config --global credential.helper store
    git config --global core.editor vim
    if [[ -n "$GIT_EMAIL" ]]; then
        printf '[user]\n\temail = %s\n' "$GIT_EMAIL" > "$HOME/.gitconfig-personal"
    fi
    if [[ -n "$WORK_EMAIL" ]]; then
        printf '[user]\n\temail = %s\n' "$WORK_EMAIL" > "$HOME/.gitconfig-work"
    fi
    if [[ ! -f "$HOME/.bashrc_private" ]]; then
        echo "  NOTE: Copy .bashrc_private.example to ~/.bashrc_private and set your WORK_EMAIL and host aliases."
    fi
    echo

    # Set default shell to bash
    if [[ "$(uname)" == "Darwin" ]]; then
        PREFERRED_BASH="/opt/homebrew/bin/bash"
        CURRENT_SHELL=$(dscl . -read ~/ UserShell 2>/dev/null | awk '{print $2}' || echo "$SHELL")
    else
        PREFERRED_BASH="/bin/bash"
        CURRENT_SHELL="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || echo "$SHELL")"
    fi
    if [[ -x "$PREFERRED_BASH" ]] && [[ "$CURRENT_SHELL" != "$PREFERRED_BASH" ]]; then
        echo "Current default shell is $CURRENT_SHELL"
        echo "Changing default shell to $PREFERRED_BASH (modern bash)..."
        chsh -s "$PREFERRED_BASH"
        echo "Default shell changed. Open a new terminal for it to take effect."
        echo
    elif [[ "$CURRENT_SHELL" == "$PREFERRED_BASH" ]]; then
        echo "Default shell is already modern bash ($PREFERRED_BASH)."
        echo
    elif [[ "$CURRENT_SHELL" == *"bash"* ]]; then
        echo "Default shell is bash ($CURRENT_SHELL)."
        echo
    else
        echo "Current default shell is $CURRENT_SHELL"
        echo "Changing default shell to bash..."
        chsh -s /bin/bash
        echo "Default shell changed. Open a new terminal for it to take effect."
        echo
    fi

    # Check and apply keyboard repeat settings (macOS only)
    if [[ "$(uname)" == "Darwin" ]]; then
        NEEDS_RESTART=false

        CURRENT_INITIAL=$(defaults read -g InitialKeyRepeat 2>/dev/null || echo "not set")
        CURRENT_REPEAT=$(defaults read -g KeyRepeat 2>/dev/null || echo "not set")

        DESIRED_INITIAL=10
        DESIRED_REPEAT=1

        if [[ "$CURRENT_INITIAL" != "$DESIRED_INITIAL" ]] || [[ "$CURRENT_REPEAT" != "$DESIRED_REPEAT" ]]; then
            echo "Configuring keyboard repeat settings..."
            echo "  Current InitialKeyRepeat: $CURRENT_INITIAL (desired: $DESIRED_INITIAL)"
            echo "  Current KeyRepeat: $CURRENT_REPEAT (desired: $DESIRED_REPEAT)"

            defaults write -g InitialKeyRepeat -int $DESIRED_INITIAL
            defaults write -g KeyRepeat -int $DESIRED_REPEAT

            NEEDS_RESTART=true
            echo
        else
            echo "Keyboard repeat settings already configured."
            echo
        fi

        # Install iTerm2 dynamic profile (macOS only)
        ITERM_DYNAMIC_PROFILES="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
        if [[ -f "$SCRIPT_DIR/iterm_profile.json" ]]; then
            mkdir -p "$ITERM_DYNAMIC_PROFILES"
            cp "$SCRIPT_DIR/iterm_profile.json" "$ITERM_DYNAMIC_PROFILES/"
            echo "iTerm2 profile installed. Restart iTerm2 and set 'DotFiles Dark' as default in Settings → Profiles."
            echo
        fi

        # Disable iTerm2 SSH shell integration (causes escape sequence leaks on remote hosts)
        defaults write com.googlecode.iterm2 sshIntegrationLevel -int 0
        echo "iTerm2 SSH shell integration disabled."
        echo

        if [[ "$NEEDS_RESTART" == "true" ]]; then
            echo "=============================================="
            echo "  RESTART REQUIRED"
            echo "  Keyboard settings have been changed."
            echo "  Please restart your computer for changes"
            echo "  to take effect."
            echo "=============================================="
            echo
        fi
    fi

    echo "  ✓ Local setup complete"
    echo


    # Reload .bashrc in all running tmux bash panes and fix session names
    if tmux list-sessions &>/dev/null; then
        echo "Fixing tmux session names..."
        while IFS= read -r line; do
            sid="${line%% *}"
            session="${line#* }"

            if [[ "$session" == "~/"* ]] || [[ "$session" == /* ]]; then
                if [[ "$session" == "~/~/"* ]]; then
                    fixed="${session#"~/"}"
                    if tmux rename-session -t "$sid" "$fixed" 2>/dev/null; then
                        echo "  fixed: $session -> $fixed"
                    else
                        echo "  failed: $session -> $fixed"
                    fi
                else
                    echo "  ok: $session"
                fi
                continue
            fi

            pane_path=$(tmux list-panes -t "$sid" -F '#{pane_current_path}' 2>/dev/null | head -1)
            expected=$(echo "$pane_path" | sed "s|^$HOME/|~/|")

            if [[ "$pane_path" == "$HOME" ]] || [[ -z "$pane_path" ]]; then
                expected="~/$session"
            fi

            if [[ "$expected" == "$session" ]]; then
                echo "  ok: $session"
            elif tmux has-session -t "=$expected" 2>/dev/null; then
                echo "  skipped: $session (session '$expected' already exists)"
            else
                if tmux rename-session -t "$sid" "$expected" 2>/dev/null; then
                    echo "  renamed: $session -> $expected"
                else
                    echo "  failed: $session -> $expected"
                fi
            fi
        done < <(tmux list-sessions -F '#{session_id} #{session_name}')
        echo

        echo "Reloading .bashrc in all tmux bash panes..."
        current_pane=$(tmux display-message -p '#{session_id}:#{window_index}.#{pane_index}' 2>/dev/null)
        while IFS= read -r line; do
            pane="${line%% *}"
            cmd="${line#* }"
            if [[ "$pane" == "$current_pane" ]]; then
                continue
            fi
            if [[ "$cmd" == "bash" ]] || [[ "$cmd" == "-bash" ]]; then
                tmux copy-mode -q -t "$pane" 2>/dev/null
                tmux send-keys -t "$pane" " exec bash --norc --noprofile ~/.local/bin/tmux_shell.sh" C-m 2>/dev/null
                echo "  reloaded: $pane"
            fi
        done < <(tmux list-panes -a -F '#{session_id}:#{window_index}.#{pane_index} #{pane_current_command}')
        echo
    fi

    if [[ $- == *i* ]]; then
        echo "Reloading .bashrc..."
        source "$HOME/.bashrc" 2>&1 || true
        echo "Environment updated. Changes are now active in this shell."
    fi
}

# --- Remote deploy ---
_run_remote() {
    if [[ ${#REMOTE_HOSTS[@]} -eq 0 ]]; then
        echo "No REMOTE_HOSTS defined in ~/.bashrc_private, skipping remote deploy."
        return
    fi

    REPO_DIR="git/twthorn/dot-files"
    FAILED=()

    for host in "${REMOTE_HOSTS[@]}"; do
        echo ""
        echo "========================================"
        echo "  HOST: $host (remote)"
        echo "========================================"
        echo ""
        echo "  Syncing private configs..."
        scp "$HOME/.bashrc_private" "$host:~/.bashrc_private"
        [[ -f "$HOME/.mcp_private.json" ]] && scp "$HOME/.mcp_private.json" "$host:~/.mcp_private.json"
        echo "  Pulling and running setup --local-only..."
        if ssh "$host" "cd ~/$REPO_DIR && git pull && ./setup.sh --local-only"; then
            RESULTS+=("  ✓ $host")
        else
            RESULTS+=("  ✗ $host (errors)")
        fi
    done
}

# --- Main ---
echo "=== Dot Files Setup ==="
RESULTS=()

# Fast path: only sync helper scripts to ~/.local/bin (local host). Skips deps,
# dotfile copy, settings merge, git config, and the tmux reload loop -- use when
# only scripts/ changed. Runs even with a dirty repo since it touches nothing
# that remote hosts pull.
if [[ "$SCRIPTS_ONLY" == "true" ]]; then
    echo "Scripts-only sync..."
    _copy_scripts
    echo ""
    echo "========================================"
    echo "  Summary:"
    echo "  ✓ $(hostname) (scripts-only)"
    echo "========================================"
    exit 0
fi

if [[ "$RUN_LOCAL" == "true" ]]; then
    if _run_local; then
        RESULTS+=("  ✓ $(hostname) (local)")
    else
        RESULTS+=("  ✗ $(hostname) (local, errors)")
    fi
fi

if [[ "$RUN_REMOTE" == "true" ]]; then
    _run_remote
fi

echo ""
echo "========================================"
echo "  Summary:"
for r in "${RESULTS[@]}"; do
    echo "$r"
done
echo "========================================"
