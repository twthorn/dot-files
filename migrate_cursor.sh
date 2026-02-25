#!/bin/bash

# Cursor Workspace Migration Script
# Migrates chat history from old Mac workspaces to new Mac workspaces
#
# Usage: ./migrate_cursor.sh [--dry-run]
#        --dry-run: Show what would be migrated without making changes

CURSOR_DIR="$HOME/Library/Application Support/Cursor/User/workspaceStorage"
DRY_RUN=false

# Parse arguments
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "=== DRY RUN MODE - No changes will be made ==="
    echo
else
    # Check if Cursor is running (only for actual migration, not dry-run)
    if pgrep -x "Cursor" > /dev/null; then
        echo "ERROR: Cursor is currently running!"
        echo
        echo "Copying database files while Cursor is running will corrupt them."
        echo "Please close Cursor completely before running this migration."
        echo
        echo "To check what needs to be migrated, run: $0 --dry-run"
        exit 1
    fi
fi

# Epoch cutoff: Feb 25, 2026 00:00:00 (1772000000)
# Files modified before this are OLD (from old Mac)
# Files modified on/after this are NEW (created on new Mac)
EPOCH_CUTOFF=1772000000

echo "Scanning workspaces in: $CURSOR_DIR"
echo "Epoch cutoff: $EPOCH_CUTOFF ($(date -r $EPOCH_CUTOFF '+%Y-%m-%d %H:%M:%S'))"
echo

# Build lists of OLD and NEW workspaces
# Format: project_path|workspace_hash|db_size
OLD_WORKSPACES=()
NEW_WORKSPACES=()

total_dirs=0
total_json=0
total_paths=0

for ws_dir in "$CURSOR_DIR"/*; do
    [[ -d "$ws_dir" ]] || continue
    ((total_dirs++))

    ws_json="$ws_dir/workspace.json"
    [[ -f "$ws_json" ]] || continue
    ((total_json++))

    # Get modification epoch
    ws_epoch=$(stat -f %m "$ws_dir" 2>/dev/null || stat -c %Y "$ws_dir" 2>/dev/null)
    ws_date=$(date -r $ws_epoch '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d @$ws_epoch '+%Y-%m-%d %H:%M:%S' 2>/dev/null)

    # Extract project folder path - handle multi-line JSON
    project_path=$(grep -E '"folder"' "$ws_json" | sed 's/.*"folder"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

    if [[ -z "$project_path" ]]; then
        if [[ $DRY_RUN == true ]]; then
            echo "DEBUG: No project path found in $(basename "$ws_dir")/workspace.json"
        fi
        continue
    fi
    ((total_paths++))

    # Normalize path (remove file:// prefix if present)
    project_path="${project_path#file://}"

    # Get workspace hash (folder name)
    ws_hash=$(basename "$ws_dir")

    # Get database size if exists
    db_file="$ws_dir/state.vscdb"
    db_size=""
    if [[ -f "$db_file" ]]; then
        db_size=$(du -h "$db_file" | awk '{print $1}')
    fi

    # Check if OLD (before cutoff) or NEW (on/after cutoff)
    if [[ $ws_epoch -lt $EPOCH_CUTOFF ]]; then
        OLD_WORKSPACES+=("$project_path|$ws_hash|$db_size")
        if [[ $DRY_RUN == true ]]; then
            echo "DEBUG: OLD - $ws_hash ($ws_date, epoch $ws_epoch) -> $project_path"
        fi
    else
        NEW_WORKSPACES+=("$project_path|$ws_hash|$db_size")
        if [[ $DRY_RUN == true ]]; then
            echo "DEBUG: NEW - $ws_hash ($ws_date, epoch $ws_epoch) -> $project_path"
        fi
    fi
done

if [[ $DRY_RUN == true ]]; then
    echo
    echo "DEBUG: Total directories: $total_dirs"
    echo "DEBUG: Directories with workspace.json: $total_json"
    echo "DEBUG: Valid project paths extracted: $total_paths"
    echo
fi

echo "Found ${#OLD_WORKSPACES[@]} OLD workspaces (from old Mac)"
echo "Found ${#NEW_WORKSPACES[@]} NEW workspaces (created on new Mac)"
echo

# Categorize workspaces
TO_MIGRATE=()
ALREADY_MIGRATED=()
NO_NEW_WORKSPACE=()

for old_entry in "${OLD_WORKSPACES[@]}"; do
    IFS='|' read -r old_project old_hash old_db_size <<< "$old_entry"

    old_db="$CURSOR_DIR/$old_hash/state.vscdb"

    # Find matching NEW workspace with same project path
    new_hash=""
    for new_entry in "${NEW_WORKSPACES[@]}"; do
        IFS='|' read -r new_project new_hash_tmp new_db_size <<< "$new_entry"
        if [[ "$old_project" == "$new_project" ]]; then
            new_hash="$new_hash_tmp"
            break
        fi
    done

    if [[ -n "$new_hash" ]]; then
        # NEW workspace exists - check if already migrated
        new_db="$CURSOR_DIR/$new_hash/state.vscdb"

        # Check if NEW database exists and is same size/newer than OLD
        # This indicates it was already copied
        if [[ -f "$new_db" && -f "$old_db" ]]; then
            new_epoch=$(stat -f %m "$new_db" 2>/dev/null || stat -c %Y "$new_db" 2>/dev/null)
            old_epoch=$(stat -f %m "$old_db" 2>/dev/null || stat -c %Y "$old_db" 2>/dev/null)

            new_size=$(stat -f %z "$new_db" 2>/dev/null || stat -c %s "$new_db" 2>/dev/null)
            old_size=$(stat -f %z "$old_db" 2>/dev/null || stat -c %s "$old_db" 2>/dev/null)

            # If NEW is newer than OLD and has data, assume already migrated
            if [[ $new_epoch -ge $old_epoch && $new_size -ge $old_size ]]; then
                ALREADY_MIGRATED+=("$old_project|$old_hash|$new_hash")
                continue
            fi
        fi

        # Not migrated yet
        TO_MIGRATE+=("$old_project|$old_hash|$new_hash|$old_db_size")
    else
        # No NEW workspace yet (project not opened on new Mac)
        NO_NEW_WORKSPACE+=("$old_project|$old_hash|$old_db_size")
    fi
done

# Display results
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "MIGRATION PLAN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

if [[ ${#TO_MIGRATE[@]} -gt 0 ]]; then
    echo "→ WILL MIGRATE (${#TO_MIGRATE[@]}):"
    for entry in "${TO_MIGRATE[@]}"; do
        IFS='|' read -r project old new db_size <<< "$entry"
        echo "  Project: $project"
        echo "  Old hash: $old (database: $db_size)"
        echo "  New hash: $new"
        echo
    done
fi

if [[ ${#ALREADY_MIGRATED[@]} -gt 0 ]]; then
    echo "✓ SKIP - Already Migrated (${#ALREADY_MIGRATED[@]}):"
    for entry in "${ALREADY_MIGRATED[@]}"; do
        IFS='|' read -r project old new <<< "$entry"
        echo "  $project"
    done
    echo
fi

if [[ ${#NO_NEW_WORKSPACE[@]} -gt 0 ]]; then
    echo "⏸ WAITING - Not Opened Yet (${#NO_NEW_WORKSPACE[@]}):"
    for entry in "${NO_NEW_WORKSPACE[@]}"; do
        IFS='|' read -r project old db_size <<< "$entry"
        echo "  $project"
    done
    echo
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY: ${#TO_MIGRATE[@]} to migrate, ${#ALREADY_MIGRATED[@]} already done, ${#NO_NEW_WORKSPACE[@]} waiting"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Perform migration if not dry-run
if [[ $DRY_RUN == true ]]; then
    echo "Dry-run mode: no changes made"
    echo "Run without --dry-run to perform migration"
    exit 0
fi

if [[ ${#TO_MIGRATE[@]} -eq 0 ]]; then
    echo "Nothing to migrate!"
    exit 0
fi

# Confirm migration
echo "Ready to migrate ${#TO_MIGRATE[@]} workspace(s)."
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled"
    exit 0
fi

echo
echo "Migrating workspaces..."
echo

# Perform migration
success_count=0
for entry in "${TO_MIGRATE[@]}"; do
    IFS='|' read -r project old new db_size <<< "$entry"

    old_db="$CURSOR_DIR/$old/state.vscdb"
    new_db="$CURSOR_DIR/$new/state.vscdb"

    echo "Migrating: $project"

    if [[ ! -f "$old_db" ]]; then
        echo "  ✗ OLD database not found: $old_db"
        continue
    fi

    if [[ ! -d "$CURSOR_DIR/$new" ]]; then
        echo "  ✗ NEW workspace directory not found: $CURSOR_DIR/$new"
        continue
    fi

    # Copy database preserving timestamps
    if cp -p "$old_db" "$new_db"; then
        echo "  ✓ Copied database"
        ((success_count++))
    else
        echo "  ✗ Failed to copy database"
    fi
    echo
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Migration complete: $success_count of ${#TO_MIGRATE[@]} successful"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "IMPORTANT: Restart Cursor for changes to take effect"
