---
description: Everything standing between a step and done — dependencies, gates, and the human items
argument-hint: <step-id>
allowed-tools: Bash, Read
---

# /blocks — What stands between this step and done?

```bash
bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" blocks $ARGUMENTS
```

Present the output, then say in one or two sentences **whose move it is**:

- dependencies not done → Claude's, unless the dependency itself is *waiting
  on you* (the output says so, with the item ids) — then it is the user's, and
  name the items;
- gates not passed → Claude's (`/step` records them);
- human items open → the user's; run `kit show <id>` for each if there are
  three or fewer and show their runbooks.

If no step id is given, run `kit status` and show the table instead, then ask
which step to expand.
