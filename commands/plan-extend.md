---
description: Safely add, split, remove, or reorder steps in PROJECT_PLAN.md
argument-hint: <add|split|remove …>
---

# /plan-extend — Edit the project plan

Safely edit PROJECT_PLAN.md. Use this to add steps, split steps, remove
steps, or reorder them.

$ARGUMENTS

## Rules

1. Read the current PROJECT_PLAN.md first.
2. Show the user what you plan to change BEFORE editing.
3. Wait for user confirmation.
4. Make the edit.
5. Validate: every step must have id, depends_on, description,
   acceptance criteria. No orphaned dependencies. Defect steps appended by
   `/qa` (id `qa-defects-<n>`) follow the same format and validate under the
   same rules.
6. Show the updated plan summary.
