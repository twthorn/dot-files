# Repository Layout
- All repos are at `~/git/<owner>/<repo>` (owner is a GitHub org or username). When given a repo name, find it there and read the code directly.
- Always prefer referencing and reading code directly over making assumptions about it.

# Research and Citations
- Back up claims by searching local repos first, then public GitHub or documentation websites. Do not rely on training knowledge alone.
- Cite sources with clickable links whenever possible — link to specific files, line numbers, or documentation sections.
- When referencing local code, use the `file_path:line_number` format. When referencing external sources, provide full URLs.

# Commits
- Always use `git commit -s` (sign-off) on all commits.
- Branch names must be: `$USER_<ticket-id>` (e.g. `tthornton_PROJ-123`)
- Never use slashes in branch names.

# PR Reviewers
- Default reviewers: %%REVIEWERS%%
- Only add reviewers when explicitly asked (e.g. "add default reviewers")

# Testing
- Follow test-driven development: write a failing test first, implement the feature, then confirm the test passes.
- Tests must exercise real code paths and assert on actual behavior. Never write tests that just assert on mocked/stubbed return values without running the logic under test. If you cannot write a meaningful test, stop and say so rather than writing a superficial one.
- After your feature tests pass, discover and run the broader test suite (CI scripts, unit tests, integration tests) to check for regressions. Search the repo for test runners, Makefiles, CI configs, and test directories.
- Do not declare work complete until both your new tests and the existing test suite pass.

# SSH Fix
When git push fails with SSH permission denied, run: `export $(tmux show-environment | grep ^SSH_AUTH_SOCK=)` before retrying.
