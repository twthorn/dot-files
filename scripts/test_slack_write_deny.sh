#!/bin/bash

# Tests _slack_write_deny_rules in setup.sh: Claude may read Slack but never post,
# react, edit canvases/lists, upload files or change read state as the user. The
# rules are tool-name globs (mcp__*__slack_send_*), so they cover the Slack MCP
# under any server name a repo gives it. Checked against the slack-mcp tool list
# with the same full-name glob matching Claude Code uses for deny rules.

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

mapfile -t RULES < <(_slack_write_deny_rules | jq -r '.[]')
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

WRITE_TOOLS=(slack_send_message slack_send_message_draft slack_schedule_message slack_add_reaction
    slack_create_canvas slack_update_canvas slack_create_conversation slack_create_list slack_update_list
    slack_add_list_comment slack_add_list_record slack_update_list_record slack_delete_list_record
    slack_get_file_upload_url slack_complete_file_upload slack_mark_read)
READ_TOOLS=(slack_read_channel slack_read_thread slack_read_canvas slack_read_file slack_read_list
    slack_read_list_comments slack_read_user_profile slack_search_public slack_search_public_and_private
    slack_search_channels slack_search_users slack_search_emojis slack_list_channel_members
    slack_list_user_channels slack_get_reactions)

check "every Slack write tool is denied" "${WRITE_TOOLS[*]} " "$(denied_among slack-mcp "${WRITE_TOOLS[@]}")"
check "no Slack read tool is denied" "" "$(denied_among slack-mcp "${READ_TOOLS[@]}")"
check "denied under another server name too" "slack_send_message " "$(denied_among chat slack_send_message)"
check "other servers' tools are untouched" "" "$(denied_among hosted-jira-mcp-prod add_comment create_issue)"

if [[ "$FAIL" -eq 0 ]]; then
    echo "ALL PASS"
else
    echo "FAILURES"
    exit 1
fi
