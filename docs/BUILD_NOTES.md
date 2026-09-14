# Build notes

## 2026-09-14 — Deck header shrinking on iPhone

The Deck folded its floating header using ScrollUpdateNotification.scrollDelta
and OverscrollNotification.overscroll. With iOS BouncingScrollPhysics, these
values describe movement after edge friction, rather than the finger's travel.
The header therefore became slow to collapse when reading the newest message.
A compact-header label could already be painted during the crossfade while its
expand button still ignored touches; the existing tests checked only that the
label existed, not that it could be tapped.

Reproduced on the signed-in iPhone 17 Pro simulator in Scratch: a 300-pixel
upward touch drag at the newest row reduced a 518.98-pixel expanded header by
only 116.70 pixels. A second 300-pixel drag still left the header 291.36 pixels
tall. The regression tests use iOS scroll physics, small touch updates and
actual hit testing rather than a single large synthetic scroll delta.

The fix uses the drag's raw primaryDelta, counts each touch update once even
when clamping emits both scroll and overscroll notifications, and preserves the
platform's bounce physics while allowing short transcripts to receive a drag.
A second regression exposed a layout jump: reaching the fully collapsed state
removed the expanded controls from the offstage header, shrinking its measured
height and changing the transcript's supposedly stable top inset. The full
header now retains its expanded layout while hidden.

Verification on the same signed-in simulator: the 300-pixel swipe now reduces
header height by 275 pixels after the gesture-recognition threshold, and the
next swipe reaches the 48-pixel compact row. A partial fold reverses cleanly;
Show the header, Hide session controls and PUSH TEST pass hit testing after
reopening. The same collapse/reveal checks pass at the simulator's larger
accessibility text settings, including its maximum (~3.12x), with no Dart
runtime exceptions or overflow. The simulator's original text size was restored.
Both suites pass: 151 kit tests and 255 Flutter tests (3 live tests skipped),
including the 3 new scroll regressions; flutter analyze is clean.

## 2026-09-14 — Codex /model and model confirmation

`/model` used to pass through the Deck as ordinary chat text; Codex's terminal
model picker is not part of app-server's chat-text protocol. The Deck now
handles the command locally, with a separate session-command entry in the
palette, an awaited model-selection callback and validation before dispatch.
Selections and attachments are not sent as prompts. Invalid selections and
host failures keep the draft available to retry.

A selection is distinct from evidence that Codex accepted a turn with that
model. The bridge pairs server thread settings with turn acceptance before
publishing confirmation, and tracks a selection revision so late events from
an earlier turn cannot confirm a new selection. Reply rows preserve the model
reported for their own turn; a server reroute updates provenance and adds a
visible note. Missing evidence and old rows remain unconfirmed/unlabelled.

`default` also needed correction: leaving the model field out of turn/start
kept Codex's previous override. The bridge now resolves the configured default
through config/read (with the catalog default as fallback) and sends that ID
explicitly. This does not edit the user's Codex configuration.

Live QA found that Codex omits thread/settings/updated when a turn keeps the
same effective settings. Requiring a fresh notification for every turn left
repeated selections pending and their replies unlabelled. Confirmation must
also accept a new turn against an unchanged, previously server-reported
configuration. The configured thread model is kept separate from a one-turn
reroute so a fallback cannot become the assumed configuration of later turns.

Final verification: 155 kit tests and 298 Flutter tests pass (3 opt-in live
tests skipped), analysis clean, and 4 iPhone integration flows pass. Signed-in
live Scratch QA verified picker selection to Luna, default reset to Astra,
correct labels on both replies, and confirmation on consecutive unchanged
Astra turns. No runtime exceptions. Selection feedback uses an inline composer
message so it cannot intercept the next Send tap.
