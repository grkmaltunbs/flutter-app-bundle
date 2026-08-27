---
description: What the human can do right now, grouped by what it needs, and what Claude works next
allowed-tools: Bash, Read
---

# /next — What can I do right now?

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" next
```

and present the output **as-is, then add one paragraph of judgement**, not a
rewrite:

- If anything is under **WOULD FLIP A STEP TODAY**, lead with it: those are the
  last open boxes on steps whose code is finished. Say which step each one
  flips.
- Then the sittings, in the order printed. The grouping is by what an item
  *needs* (a console, a phone, your eyes, a decision…) so that one sitting
  clears a group. Do not regroup by step.
- Anything under **unsorted** is an item nobody has classified. Offer to
  classify it if the user tells you what it needs — then set `needs:` in
  `plan/items/<id>.yaml` and run `kit validate`.
- Finish with the **CLAUDE** line: the next step, and whether it is ready or
  blocked.

If `$ARGUMENTS` names an item or step id, run `kit show <id>` instead and
present that: for an item, its runbook (do / expect / if not) or its question
with the recommended option first; for a step, its state and what blocks it.

Never mark anything done from this command. That is `/done`.
