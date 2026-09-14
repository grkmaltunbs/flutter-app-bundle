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
