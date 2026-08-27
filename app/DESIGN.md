# flutter-kit app — phase 2 design note

Written 2026-08-28 as the handoff from phase 1. Read this before writing any
app code. Decisions here were taken with the user; the *Open* section is what
still needs them.

## What phase 1 built (and what the app builds on)

- `kit/` — the plan engine. `plan/kit.yaml`, `plan/steps/<id>.yaml`,
  `plan/items/<id>.yaml`; state computed by `graph.dart`; `kit` CLI
  (`next`, `blocks`, `done`, `gate`, `step`, `item new`, `inbox`, `render`,
  `import`, `validate`). Schema: `../schema/README.md`. 48 tests.
- The **board** — `kit render board` — two tabs over one plan: *Steps*
  (bubbles by dependency depth via `dag_layout.dart`; tap → panel with comes
  after / unlocks / what you should do as runbooks / the step's own spec) and
  *Your work* (items grouped by what they need, flip-today first, decisions
  with the recommended option first). Ticks, answers and notes are a
  browser-local draft; **Send to Claude** publishes the page to itself with a
  `#kit-outbox` batch; `kit inbox` applies it. Proven end to end on
  2026-08-28 (one real Send, picked up by the watching session in seconds).
- Nahmatik is the first consumer: `~/StudioProjects/nahmatik/plan/`, its
  commands go through `tool/kit.sh` → this checkout.

**The app is the same two screens on the same data**, plus the thing the
page cannot do: drive the user's own Claude Code.

## Decisions taken

| decision | answer | why |
|---|---|---|
| Shell | Flutter — one codebase for macOS, Windows, iOS, Android | the user's stack; the desktop build can spawn `claude` itself, so there is no separate daemon |
| Who talks to Claude | the **desktop app**, by running the user's own installed Claude Code (`claude -p … --output-format stream-json`, non-bare, under their login) | personal use; the docs' only prohibition is offering claude.ai login to *others* in a product. API key stays a config knob. `--bare` will become the `-p` default one day — pass the non-bare form explicitly |
| Phone ↔ Mac transport | **Firestore on `flutterappbundle`** (europe-west3, Email/Password auth — enabled 2026-08-28; `app/firebase.json` + closed rules placeholder) | no open ports, works off Wi-Fi, one user, a stack the user knows. Never touch a consumer app's Firebase project |
| First screens | Steps (bubbles + panel) and Your work (grouped), mirroring the board; ticks batch behind a **Send to Claude** button — never per tick | the user's explicit ask on 2026-08-28 |
| Auth for the relay | one user, Email/Password; rules allow only that uid | the app is not a product |

## Architecture sketch

```
┌──────────── macOS / Windows app (host) ─────────────┐
│ reads plan/ of the open project (kit as a library)   │
│ renders Steps + Your work                            │
│ spawns `claude -p` for /step, /qa, chat              │  ← subscription login,
│ hooks: PreToolUse → permission prompt in the UI      │     the user's own CLI
│ mirrors state + inbox to Firestore (flutterappbundle)│
└──────────────────────────┬──────────────────────────┘
                           │ Firestore: projects/{id}/{plan snapshot, events, inbox}
┌──────────────────────────┴──────────────────────────┐
│ iPhone / Android app (remote)                        │
│ same two screens, from the snapshot                  │
│ ticks/answers/notes → local draft → Send → inbox     │
│ permission prompts + AskUserQuestion → answer here   │
└──────────────────────────────────────────────────────┘
```

- **kit as a library.** The Flutter app depends on `../kit` (path dependency)
  for the model, graph, validate, and inbox logic. No second implementation.
- **The host owns the truth.** `plan/` on disk is authoritative; Firestore
  holds a snapshot the host writes and an `inbox` the remote writes. The host
  applies inbox batches with the same code as `kit inbox`.
- **Bridge to Claude Code.** `claude -p "<prompt or /command>" --output-format stream-json --input-format stream-json --verbose --include-partial-messages [--resume <id>]`.
  Slash commands work in `-p`. Permission prompts: a `PreToolUse` hook that
  asks the host over a local socket and waits (the channels *permission
  relay* is the first-party alternative when it leaves research preview);
  `AskUserQuestion` is disabled under `-p` per the docs — the host renders
  the question itself when it sees the tool call in the stream. Verify all
  of this in a spike before building UI on it.
- **Events for the board.** Hooks (`Stop`, `PostToolUse`) post to the host;
  the host updates the snapshot; the remote sees gates flip live.

## Open — the user's, before building

1. **iPhone distribution**: TestFlight (needs an App Store Connect record,
   an upload per build) or a Flutter **web** build on Firebase Hosting (Add
   to Home Screen, no signing). Recommendation: web first, TestFlight later.
2. **What the phone can trigger**: read-only + Send (safe), or also run
   `/step` / `/qa` remotely (the Mac must be awake; usage counts the same).
3. **Firestore rules** for `flutterappbundle` — one uid, written when auth
   exists; the placeholder denies everything.

## Spike list (do these before any screen)

1. `claude -p "/plan-status" --output-format stream-json` from a Dart
   `Process` — confirm slash commands, session ids, `--resume`.
2. A `PreToolUse` hook that blocks on a local socket answer — confirm the
   hook can wait, and what the timeout is.
3. Read a `#kit-outbox` from Firestore instead of the page; apply with the
   library; regenerate.
4. Flutter macOS build spawning `claude` with the user's environment
   (PATH, keychain) — the app is not a shell; confirm login is found.
