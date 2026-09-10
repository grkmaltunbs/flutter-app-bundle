---
name: kit-plan-status
description: "Show plan progress — every step's state, what each waits on, and the next step"
---

> **Where things are.** This file is `skills/kit-plan-status/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Before anything else set, in the shell, `PLUGIN` to that root (Claude Code: `${CLAUDE_PLUGIN_ROOT}`) and `KIT="$PLUGIN/kit/kit.sh"`; every `kit` command below runs as `bash "$KIT" …`, in the project folder. `$ARGUMENTS` means the words after `$kit-plan-status` in the user's message. Agents named in bold (flutter-tester, flutter-qa, …) are the Codex custom agents `$kit-codex-setup` installs into the project's `.codex/agents/`; spawn them by name, and where one is not installed do that part yourself.


# $kit-plan-status — Show plan progress

```bash
bash "$KIT" status
```

Show the table as printed. The **state** column is computed from the files,
not stored, so it cannot be stale:

| state | meaning |
|---|---|
| `done` | finished |
| `ready` | every dependency done — Claude can start it |
| `blocked` | a dependency is not done |
| `active` | being worked; a gate is still pending |
| `code complete` | every gate passed; only human items remain — **the user's move** |
| `FLIP ME` | gates passed, nothing blocks it — run `kit step done <id>` |

Then one sentence: the next step for Claude (the last line of the output),
and how many steps are code-complete waiting on the user, if any — those are
the ones to point at `$kit-next`.

If the project has no `plan/` directory, say so and point at `$kit-init-app`
(new project) or `kit import` (a project with a hand-written `PROJECT_PLAN.md`).
