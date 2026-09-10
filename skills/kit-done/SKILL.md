---
name: kit-done
description: "Close a human item (or drop it), and see what it unblocked"
---

> **Where things are.** This file is `skills/kit-done/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Before anything else set, in the shell, `PLUGIN` to that root (Claude Code: `${CLAUDE_PLUGIN_ROOT}`) and `KIT="$PLUGIN/kit/kit.sh"`; every `kit` command below runs as `bash "$KIT" …`, in the project folder. `$ARGUMENTS` means the words after `$kit-done` in the user's message. Agents named in bold (flutter-tester, flutter-qa, …) are the Codex custom agents `$kit-codex-setup` installs into the project's `.codex/agents/`; spawn them by name, and where one is not installed do that part yourself.


# $kit-done — I did this one

`$ARGUMENTS` is an item id, optionally followed by `--drop` (close it as "not
doing") and/or a short note. If no id is given, run `kit next` and ask which.

1. **Show it first.** `kit show <id>` — read the runbook or question back so
   the user is closing the thing they think they are.

2. **If the item has `verify:` lines in its runbook**, offer to run them
   before closing (they are shell commands that read a state back — a deployed
   function's runtime, a DNS answer, a Firestore document). If a verify fails,
   say so and do not close the item unless the user insists.

3. **If the item is a decision** (it has a `question:`), the note is the
   answer. Record it: set `question.answer` in `plan/items/<id>.yaml` (patch
   the file, keep everything else), then close.

4. Close it:

   ```bash
   bash "$KIT" done <id> --note "<note>"
   # or, for --drop:
   bash "$KIT" drop <id> --note "<note>"
   ```

   The output says what moved: a step that now has nothing in its way
   (`kit step done <step>` closes it — do that, it is the whole point), a step
   still waiting on other items, or a step that became startable.

5. **Re-render the views** so nothing reads stale:

   ```bash
   bash "$KIT" render plan
   bash "$KIT" render board
   ```

   The flutter-kit app shows the change as soon as `plan/` changes; the
   artifact page is republished only on demand with `$kit-board`.

Never close an item the user did not name. Never `--force` a step.
