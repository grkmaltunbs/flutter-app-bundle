---
description: Review code and present prioritized findings — read-only, never auto-fixes
argument-hint: [files or scope]
allowed-tools: Read, Grep, Glob, Bash, Task, TodoWrite
---

Review code: $ARGUMENTS

Delegate to the **flutter-reviewer** agent.

If $ARGUMENTS is empty, review uncommitted changes (`git diff`). Otherwise
review the named files / feature.

The agent returns a prioritized list (Blockers / Important / Minor / Analyzer
output). Present the full list to the user. This command is **read-only** —
it never edits code. ASK the user before routing any fixes; only on their
approval hand Blockers to the appropriate agent (developer for code fixes,
tester for missing tests) as a follow-up.

If any Blocker involves Firebase project mis-targeting (any reference to
the wrong project ID), stop and surface to the user immediately — never
touch infrastructure issues from this command.
