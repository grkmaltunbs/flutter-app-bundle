---
description: Refresh this project's flutter-kit files (permissions + Flutter rules) after a plugin update
allowed-tools: Read, Write, Edit, Bash
---

# /kit-sync — Refresh the kit files pinned into this project

Most of flutter-kit lives in the plugin and updates automatically. Two things
can't: **permissions** (plugins cannot ship them) and **`docs/flutter-rules.md`**
(`CLAUDE.md` `@`-imports it, and `@`-imports can't reach the plugin directory).
Both get copied into the project at `/init-app` time and go stale from then on.

This command re-syncs them. Run it after installing the plugin on an existing
project, and after any plugin update.

---

## Part 1 — Permissions

Source: `${CLAUDE_PLUGIN_ROOT}/templates/settings.json.template`
Target: `.claude/settings.json`

1. Read both (the target may not exist).

2. **If the target does not exist**, create `.claude/` and write the template
   through unchanged. Skip to Part 1 reporting.

3. **If it exists, merge — never overwrite:**
   - `permissions.allow` — union. Add template entries the project lacks.
   - `permissions.deny` — union. Add template entries the project lacks.
   - `permissions.ask` — leave the project's list untouched.
   - `enabledPlugins` — add template keys the project lacks; never remove.
   - **Any other key** the project has (`hooks`, `env`, `model`, …) — leave
     exactly as-is. This command only ever adds.
   - Never remove an entry the project already had, even if it is absent from
     the template. The user may have trimmed the list deliberately.

4. Preserve the project's existing formatting and key order where practical;
   append additions at the end of each list.

5. **Report**: list the entries added to `allow`/`deny`. If nothing changed, say
   "permissions already in sync" and do not rewrite the file. Flag any conflict
   (an entry the project denies that the template allows, or vice versa) and
   leave the project's version in place.

6. **Flag the broad ones.** If this run added any of `Bash(rm *)`,
   `Bash(git push *)`, `Bash(git reset --hard *)`, `Bash(flutter run *)`, or
   `Bash(npm install *)`, list them explicitly and tell the user they can trim
   any they don't want. These are broad by design so build loops don't stall —
   but the trust decision is the user's.

---

## Part 2 — Flutter rules

Source: `${CLAUDE_PLUGIN_ROOT}/reference/flutter-rules.md`
Target: `docs/flutter-rules.md`

1. If the target does not exist, copy it in and report that.

2. If it exists, **diff before replacing**:
   ```bash
   diff -u docs/flutter-rules.md "${CLAUDE_PLUGIN_ROOT}/reference/flutter-rules.md"
   ```
   - Identical → report "rules already in sync", change nothing.
   - Differences → summarise them by section (don't dump the whole diff), then
     **ask before overwriting**. The project may have deliberately customised
     its rules; this file is project-owned once written.

3. If the user has local customisations they want to keep, offer to merge the
   upstream changes into their version rather than replacing it wholesale.

4. Never touch the `@docs/flutter-rules.md` import line in `CLAUDE.md` — the
   path is correct and project-relative by design.

---

## Rules
- Emit valid JSON. Validate before writing (`python3 -m json.tool`).
- Never write outside the project (`.claude/settings.json`, `docs/flutter-rules.md`).
- Never edit `${CLAUDE_PLUGIN_ROOT}/` — it is read-only and wiped on update.
- If the existing settings file is malformed JSON, stop and show the parse
  error rather than guessing at a repair.
- Report both parts, even when one was a no-op.
