---
name: kit-blocks
description: "Everything standing between a step and done — dependencies, gates, and the human items"
---

> **Where things are.** This file is `skills/kit-blocks/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Before anything else set, in the shell, `PLUGIN` to that root (Claude Code: `${CLAUDE_PLUGIN_ROOT}`) and `KIT="$PLUGIN/kit/kit.sh"`; every `kit` command below runs as `bash "$KIT" …`, in the project folder. `$ARGUMENTS` means the words after `$kit-blocks` in the user's message. Agents named in bold (flutter-tester, flutter-qa, …) are the Codex custom agents `$kit-codex-setup` installs into the project's `.codex/agents/`; spawn them by name, and where one is not installed do that part yourself.


# $kit-blocks — What stands between this step and done?

```bash
bash "$KIT" blocks $ARGUMENTS
```

Present the output, then say in one or two sentences **whose move it is**:

- dependencies not done → Claude's, unless the dependency itself is *waiting
  on you* (the output says so, with the item ids) — then it is the user's, and
  name the items;
- gates not passed → Claude's (`$kit-step` records them);
- human items open → the user's; run `kit show <id>` for each if there are
  three or fewer and show their runbooks.

If no step id is given, run `kit status` and show the table instead, then ask
which step to expand.
