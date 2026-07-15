# Repository Layout
- All repos are at `~/git/<owner>/<repo>` (owner is a GitHub org or username). When given a repo name, find it there and read the code directly.
- Always prefer referencing and reading code directly over making assumptions about it.

# Research and Citations
- Back up claims by searching local repos first, then public GitHub or documentation websites. Do not rely on training knowledge alone.
- Cite sources with clickable links whenever possible — link to specific files, line numbers, or documentation sections.
- Prefer GitHub web links (github.com or enterprise GitHub URLs) over local file paths so they are clickable in the terminal. Include the branch/commit and line number anchor (e.g. `#L42-L50`) when relevant.

# Commits
- Always use `git commit -s` (sign-off) on all commits.
- Branch names must be: `$USER_<ticket-id>` (e.g. `tthornton_PROJ-123`)
- Never use slashes in branch names.

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
