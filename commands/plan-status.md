---
description: Show plan progress — every step's state, what each waits on, and the next step
allowed-tools: Bash
---

# /plan-status — Show plan progress

```bash
bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" status
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
the ones to point at `/next`.

If the project has no `plan/` directory, say so and point at `/init-app`
(new project) or `kit import` (a project with a hand-written `PROJECT_PLAN.md`).
