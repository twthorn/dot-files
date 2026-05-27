# Repository Layout
- All repos are at `~/git/<owner>/<repo>` (owner is a GitHub org or username). When given a repo name, find it there and read the code directly.
- Always prefer referencing and reading code directly over making assumptions about it.

# Branch Naming
- Branch names must be: `$USER_<ticket-id>` (e.g. `tthornton_PROJ-123`)
- Never use slashes in branch names.

# PR Reviewers
- Default reviewers: %%REVIEWERS%%

# SSH Fix
When git push fails with SSH permission denied, run: `export $(tmux show-environment | grep ^SSH_AUTH_SOCK=)` before retrying.
