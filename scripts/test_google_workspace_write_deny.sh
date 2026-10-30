#!/bin/bash

# Tests _google_workspace_write_deny_rules in setup.sh: Claude may read Gmail,
# Calendar, Drive, Docs, Sheets, Slides, Forms and Tasks and create new things
# (files, copies, conversions, uploads, folders, drafts, events, tasks, labels,
# filters), but never change existing ones -- no editing, formatting, commenting,
# moving, renaming, sharing, completing -- or send mail. Checked against the google-workspace tool list with
# the same full-name glob matching Claude Code uses for deny rules.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/../setup.sh"

FAIL=0
check() { # desc expected actual
    if [[ "$2" == "$3" ]]; then
        echo "  ok: $1"
    else
        echo "  FAIL: $1 (expected '$2', got '$3')"
        FAIL=1
    fi
}

mapfile -t RULES < <(_google_workspace_write_deny_rules | jq -r '.[]')
is_denied() { # tool name
    local rule
    for rule in "${RULES[@]}"; do
        # shellcheck disable=SC2053
        [[ "$1" == $rule ]] && return 0
    done
    return 1
}
denied_among() { # server tool...
    local server="$1" tool; shift
    for tool in "$@"; do
        is_denied "mcp__${server}__$tool" && echo "$tool"
    done | tr '\n' ' '
}

WRITE_TOOLS=(calendar_update
    docs_add_list docs_create_comment docs_edit
    docs_format_paragraph docs_format_text docs_insert_table docs_insert_text docs_replace_range docs_reply_comment
    drive_move drive_rename drive_share
    forms_add_item forms_move_item forms_update_info forms_update_item forms_update_settings
    gmail_batch_modify gmail_modify gmail_reply
    gmail_send gmail_update_draft
    sheets_add_chart sheets_add_named_range sheets_add_pivot_table sheets_add_protected_range sheets_add_sheet
    sheets_append_values sheets_batch_update_values sheets_conditional_format sheets_data_validation
    sheets_duplicate_sheet sheets_format_cells sheets_insert_dimension sheets_rename_sheet sheets_resize_freeze
    sheets_set_hyperlink sheets_update_values
    slides_add_slide slides_create_line slides_create_table slides_create_text_box
    slides_duplicate_slide slides_format_paragraph slides_format_text slides_insert_text slides_move_element
    slides_reorder slides_replace_text slides_set_background slides_set_speaker_notes
    tasks_complete tasks_update)
READ_TOOLS=(authenticate complete_authentication auth_disconnect directory_search meeting_notes_search
    calendar_events calendar_find_times calendar_list
    docs_comments docs_export_markdown docs_get docs_get_hyperlinks docs_get_structure docs_revisions docs_search
    drive_download drive_get_permissions drive_list_folder drive_list_shared_drives drive_search
    forms_get forms_get_response forms_list_responses forms_search
    gmail_get gmail_get_draft gmail_get_filter gmail_list_drafts gmail_list_filters gmail_search
    sheets_batch_get_values sheets_get_hyperlinks sheets_get_metadata sheets_get_values sheets_search
    slides_get slides_search tasks_get tasks_list tasks_list_tasklists)
CREATE_TOOLS=(docs_create docs_create_formatted sheets_create slides_create forms_create
    slides_convert docs_convert drive_copy drive_create_folder drive_upload drive_create_shortcut
    gmail_create_draft gmail_create_label gmail_create_filter calendar_create_event tasks_create)

check "every Google Workspace write tool is denied" "${WRITE_TOOLS[*]} " "$(denied_among google-workspace "${WRITE_TOOLS[@]}")"
check "no Google Workspace read tool is denied" "" "$(denied_among google-workspace "${READ_TOOLS[@]}")"
check "creating new things is allowed" "" "$(denied_among google-workspace "${CREATE_TOOLS[@]}")"
check "other servers' tools are untouched" "" "$(denied_among hosted-jira-mcp-prod create_issue edit_issue add_comment)"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
