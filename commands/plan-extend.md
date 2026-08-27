---
description: Add, split, remove, or reorder plan steps — and add human items
argument-hint: <add|split|remove|reorder|item …>
allowed-tools: Bash, Read, Write, Edit
---

# /plan-extend — Edit the plan

The plan is `plan/steps/<id>.yaml` and `plan/items/<id>.yaml`. `PROJECT_PLAN.md`
is **generated** from them — never edit it by hand.

$ARGUMENTS

## Rules

1. Run `kit status` first and read the step(s) involved with `kit show <id>`.
2. **Show the user what you plan to change before editing**, as the YAML you
   will write. Wait for confirmation.
3. Make the edit:
   - **add** — copy `${CLAUDE_PLUGIN_ROOT}/templates/plan/step.yaml.template`
     to `plan/steps/<id>.yaml`. Pick `rank` so the step lands where it should
     be worked (ranks are integers; leave gaps — the importer used steps of
     10). Set `number` to the display number the user wants; **ids never
     change, numbers may.** `depends_on` names ids.
   - **split** — the new step gets its own id and rank; move the relevant
     sections; items that blocked the old step keep blocking the half they
     belong to.
   - **remove** — refuse if any step's `depends_on` names it or any item
     `blocks` it; show the references instead.
   - **reorder** — change `rank` only.
   - **item** — a human item: copy
     `${CLAUDE_PLUGIN_ROOT}/templates/plan/item.yaml.template` to
     `plan/items/<id>.yaml`, or run
     `kit item new --id <id> --title "<title>" --needs <a,b> --blocks <step> --from <origin>`.
     Every item says what it **needs** (`console`, `device`, `read`, `look`,
     `decision`, `store`, `money`, `secret`) and, if it gates a step, names it
     in `blocks:`. A runbook is `do` / `expect` / `if_fails` lines, with an
     optional `verify:` shell command. A decision carries a `question:` with
     exactly one `recommended: true` option.
4. Validate — this is the gate, not a formality:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" validate
   ```

   Errors must be fixed before you report success.
5. Re-render the views: `kit render plan` and `kit render board`.
6. Show `kit status` and say what changed.

Defect steps appended by `/qa` (id `qa-defects-<n>`) follow the same rules.
