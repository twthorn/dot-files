# Repository Layout
- All repos are at `~/git/<owner>/<repo>` (owner is a GitHub org or username). When given a repo name, find it there and read the code directly.
- This layout is identical on every machine (local and all remote hosts) — a repo at `~/git/slack/viz` locally is at `~/git/slack/viz` on every box. Never assume a different path from a repo's own docs; if a checked-in CLAUDE.md or README references a path like `~/viz`, treat it as stale and use `~/git/<owner>/<repo>`.
- Always prefer referencing and reading code directly over making assumptions about it.

# Research and Citations
- Back up claims by searching local repos first, then public GitHub or documentation websites. Do not rely on training knowledge alone.
- Cite sources with clickable links whenever possible — link to specific files, line numbers, or documentation sections.
- Prefer GitHub web links (github.com or enterprise GitHub URLs) over local file paths so they are clickable in the terminal. Include the branch/commit and line number anchor (e.g. `#L42-L50`) when relevant.

# Commits
- Always use `git commit -s` (sign-off) on all commits.
- Branch names must be: `$USER_<ticket-id>` (e.g. `tthornton_PROJ-123`)
- Never use slashes in branch names.

# Jira Tickets
- Branch names embed a ticket ID (`$USER_<ticket-id>`). Before creating a branch, confirm that ticket exists in Jira (search/get it via the Jira MCP). If it does not exist, create it first, then name the branch after the new ticket's key.
- Create new tickets in the `%%JIRA_PROJECT%%` project and assign them to `%%JIRA_ASSIGNEE%%` (fall back to the Jira `me` resource if that value is empty).
- Add every new ticket to the project's latest sprint: find the current active sprint on the `%%JIRA_BOARD%%` board (if none is active, the most recent upcoming one) and set the ticket's Sprint field. Discover the Sprint custom field's ID via the Jira fields resource rather than guessing.
- Give every new ticket a parent epic. Search the project's open epics and pick the most relevant one for the work — the initiative or theme it belongs to; the current fiscal year or quarter in an epic's name (e.g. `FY27 Q3`) is another signal to look for. Set it via the Epic Link field. If no suitable epic exists, say so and ask rather than creating one.
- Fill the ticket with full context so it stands on its own and the eventual PR is meaningfully linked to it: a clear summary, the problem/goal, the plan or approach, and any relevant links (repo, related tickets, docs).
- Use the Jira MCP tools (`create_issue`, `edit_issue`) for all of this. If a field or transition fails, relay the exact error rather than guessing.

# Pull Requests
- Before writing a PR description, find and read the repo's PR template, and follow it exactly. Check `.github/PULL_REQUEST_TEMPLATE.md`, `.github/PULL_REQUEST_TEMPLATE/`, `PULL_REQUEST_TEMPLATE.md`, and `docs/`. Never write the PR body freehand when a template exists.
- Reproduce every section heading from the template verbatim and in order, and fill each with meaningful, specific content. Do not drop, rename, reorder, or leave a required section empty.
- Sections like `## Test Plan`, `## Rollout Plan`, and `## Revert Plan` are mandatory whenever the template lists them: describe how the change was validated, how it reaches production, and the concrete steps to roll it back.
- If a section genuinely does not apply, keep the heading and write why (e.g. "N/A — config-only, no rollout") rather than deleting it.
- After drafting, re-read the template and confirm every required section is present with real content before creating the PR.

# PR Reviewers
- Default reviewers: %%REVIEWERS%%
- Only add reviewers when explicitly asked (e.g. "add default reviewers")

# Code Style
- Write self-documenting code with clear variable names, function names, and test names. Default to no comments.
- Only add comments when behavior is genuinely non-obvious and cannot be clarified through naming or structure alone.
- Exception: if surrounding code already uses comments as part of its structure, match that style.

# Implementation Approach
- Before writing any code, first check whether the functionality already exists or can be accomplished with existing code.
- If new code is needed, search the codebase for analogous implementations — similar interfaces, classes, or functionality.
- Study how they are structured, tested, and integrated. Mirror their patterns in your implementation.

# Testing
- Follow test-driven development: write a failing test first, implement the feature, then confirm the test passes.
- Tests must exercise real code paths and assert on actual behavior. Never write tests that just assert on mocked/stubbed return values without running the logic under test. If you cannot write a meaningful test, stop and say so rather than writing a superficial one.
- After your feature tests pass, discover and run the broader test suite (CI scripts, unit tests, integration tests) to check for regressions. Search the repo for test runners, Makefiles, CI configs, and test directories.
- Do not declare work complete until both your new tests and the existing test suite pass.

# SSH Fix
When git push fails with SSH permission denied, run: `export $(tmux show-environment | grep ^SSH_AUTH_SOCK=)` before retrying.
