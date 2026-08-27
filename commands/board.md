---
description: Regenerate the board from plan/ and republish it at its standing URL
allowed-tools: Bash, Read, Artifact
---

# /board — Regenerate and republish the board

The board is **generated, never edited**. Its source is `plan/`; its HTML is
written to the path in `plan/kit.yaml` → `board.output`; its standing URL is
`board.artifact_url`.

1. Validate first — a broken plan must not become a published page:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" validate
   ```

   Errors → fix them (or tell the user) and stop. Warnings → continue, and
   mention them.

2. Render:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" render board
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" render plan
   ```

3. Publish with the Artifact tool. Pass `board.artifact_url` as `url` so the
   user's bookmark keeps working; if the manifest has no URL yet, publish
   without one, then write the returned URL into `plan/kit.yaml` under
   `board.artifact_url` so the next run updates instead of duplicating.
   Favicon: keep whatever the page used before; if this is the first publish,
   use 🧭.

4. Read comments on the page (`action: "comments"`) and report any that are
   new. A comment is anchored to a card; **the card's id is the item id**.
   "done" on a card means `/done <id>`; a single word like "console" or
   "device" on an unsorted card is its `needs:`; an answer on a decision card
   is `question.answer`. Act on what the user has told you to act on, and
   list the rest.

Do not hand-edit the HTML. If the page needs to look different, the change
goes in the plugin's renderer or in `board.fonts` / `board.colors` in
`plan/kit.yaml`.
