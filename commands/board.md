---
description: Pick up what the user sent from the board, regenerate it from plan/, and republish at its standing URL
allowed-tools: Bash, Read, Artifact
---

# /board — Pick up, regenerate, republish

The board is **generated, never edited**. Its source is `plan/`; its HTML is
written to `plan/kit.yaml` → `board.output`; its standing URL is
`board.artifact_url`. The page can also **send** — ticks, chosen answers and
notes the user batched with *Send to Claude* — by publishing a new version of
itself with the batch inside. This command is the other half of that loop.

1. **Pick up what was sent.** Read the live page with the Artifact tool
   (`action: "read"`, `url` = `board.artifact_url`). If the content came back
   as a file path, grep it; either way look for
   `<script type="application/json" id="kit-outbox">…</script>`. If present,
   save its contents (JSON; `<` sequences are ordinary JSON escapes) to
   a scratch file and apply:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" inbox <scratch>/outbox.json --dry-run   # read it back to the user first
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" inbox <scratch>/outbox.json
   ```

   Tell the user what landed: which items closed, which answers were
   recorded, which notes were attached. A note on a step is the user talking
   to you about that step — read it and act on it or answer it. If `inbox`
   reports a step with nothing left in the way, close it with
   `kit step done <id>`. No outbox means nothing was sent — say so and carry on.

2. **Also read comments** (`action: "comments"`). A comment is anchored to a
   card or a bubble; **the element's id is the item or step id**. "done" on a
   card means `kit done <id>`; a single word like `console` or `device` on a
   card is its `needs:`; an answer on a decision card is `question.answer`.
   Act on what the user told you to act on and list the rest.

3. **Validate** — a broken plan must not become a published page:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" validate
   ```

   Errors → fix them (or tell the user) and stop. Warnings → continue.

4. **Render** both views:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" render board
   bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh" render plan
   ```

5. **Publish** with the Artifact tool, passing `board.artifact_url` as `url`
   (same link, new version) **and** `capabilities: {"artifact": {}}` — that
   is what lets the page send. If the manifest has no URL yet, publish
   without one, then write the returned URL into `plan/kit.yaml` under
   `board.artifact_url`. Keep the favicon the page had before (🧭 on a first
   publish). Offer to commit `plan/`, the rendered plan and the board.

Do not hand-edit the HTML. If the page should look different, the change
goes in the plugin's renderer or in `board.fonts` / `board.colors` in
`plan/kit.yaml`.
