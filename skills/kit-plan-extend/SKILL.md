---
name: kit-plan-extend
description: "Add, split, remove, or reorder plan steps — and add human items"
---

> **Where things are.** This file is `skills/kit-plan-extend/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Before anything else set, in the shell, `PLUGIN` to that root (Claude Code: `${CLAUDE_PLUGIN_ROOT}`) and `KIT="$PLUGIN/kit/kit.sh"`; every `kit` command below runs as `bash "$KIT" …`, in the project folder. `$ARGUMENTS` means the words after `$kit-plan-extend` in the user's message. Agents named in bold (flutter-tester, flutter-qa, …) are the Codex custom agents `$kit-codex-setup` installs into the project's `.codex/agents/`; spawn them by name, and where one is not installed do that part yourself.


# $kit-plan-extend — Edit the plan

The plan is `plan/steps/<id>.yaml` and `plan/items/<id>.yaml`. `PROJECT_PLAN.md`
is **generated** from them — never edit it by hand.

$ARGUMENTS

## Rules

1. Run `kit status` first and read the step(s) involved with `kit show <id>`.
2. **Show the user what you plan to change before editing**, as the YAML you
   will write. Wait for confirmation.
3. Make the edit:
   - **add** — copy `$PLUGIN/templates/plan/step.yaml.template`
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
     `$PLUGIN/templates/plan/item.yaml.template` to
     `plan/items/<id>.yaml`, or run
     `kit item new --id <id> --title "<title>" --needs <a,b> --blocks <step> --from <origin>`.
     Every item says what it **needs** (`console`, `device`, `read`, `look`,
     `decision`, `store`, `money`, `secret`, `know`) and, if it gates a step, names it
     in `blocks:`. A runbook is `do` / `expect` / `if_fails` lines, with an
     optional `verify:` shell command. A decision carries a `question:` with
     exactly one `recommended: true` option.
4. Validate — this is the gate, not a formality:

   ```bash
   bash "$KIT" validate
   ```

   Errors must be fixed before you report success.
5. Re-render the views: `kit render plan` and `kit render board`.
6. Show `kit status` and say what changed.

Defect steps appended by `$kit-qa` (id `qa-defects-<n>`) follow the same rules.
