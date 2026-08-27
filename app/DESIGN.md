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
| Shell | Flutter — macOS host app; **Android phone app first**, iPhone later | the user's stack and the user's phone. An Android APK installs directly (`flutter build apk`), no store, no signing ceremony |
| How the phone runs commands | **Claude Code Remote Control**, not a chat of our own. The Mac app starts `claude --remote-control` (or `claude remote-control`) in the project; the Claude Android app drives it — `/step`, `/qa`, `/context`, `/compact`, permission prompts, plan mode, all of it | the user wants every command from the phone (2026-08-28). Remote Control gives the whole interactive session on the subscription, first-party, today; `-p` would give less (interactive prompts disabled) for far more code |
| What our app does | the two board screens (Steps bubbles + panel, Your work + Send to Claude), a **session launcher/monitor** on the Mac (start, name, stop, "open in Claude" link), and **live progress** of a running `/step` (gates flipping, tests running) from hooks | the parts Remote Control does not have |
| Phone ↔ Mac transport for the board | **Firestore on `flutterappbundle`** (europe-west3, Email/Password auth, enabled 2026-08-28) | no open ports, works off Wi-Fi, one user. The session itself travels over Remote Control (Anthropic's servers), not Firestore |
| Ticks | batch behind **Send to Claude** — never per tick | the user's explicit ask |
| Auth for Claude | the user's own Claude Code login; API key stays a config knob | personal use; the only documented prohibition is offering claude.ai login to *others* |

## Architecture sketch

```
┌──────────── macOS app (host) ───────────────────────────┐
│ reads plan/ of the open project (kit as a library)       │
│ Steps + Your work (same as the phone)                    │
│ session launcher: spawns `claude --remote-control        │
│   --name <project>` in the project dir; shows its state  │──── Remote Control ───┐
│ hooks (Stop, PostToolUse, SessionStart) → events         │     (Anthropic)       │
│ applies inbox batches with the same code as `kit inbox`  │                       │
│ mirrors plan snapshot + events to Firestore              │                       ▼
└───────────────────────────┬──────────────────────────────┘        Claude Android app
                            │ Firestore (flutterappbundle):        drives the session:
                            │ projects/{id}: snapshot, events, inbox   /step /qa /compact …
┌───────────────────────────┴──────────────────────────────┐
│ Android app (remote)                                      │
│ Steps + Your work from the snapshot                       │
│ ticks/answers/notes → draft → Send → inbox                │
│ live progress of the running step (from events)          │
│ "Open in Claude" → the Remote Control session             │
└───────────────────────────────────────────────────────────┘
```

- **kit as a library.** The Flutter apps depend on `../kit` (path dependency)
  for model, graph, validate, inbox. No second implementation.
- **The host owns the truth.** `plan/` on disk is authoritative; Firestore
  holds a snapshot the host writes and an `inbox` the phone writes.
- **Headless runs stay possible** for a button like "run /qa now" from the
  phone while no interactive session is open: `claude -p "/qa" --output-format
  stream-json` from the host, progress streamed to Firestore. Optional; the
  interactive session is the main path.

## Open — nothing blocking

The two earlier questions are answered (Android first; the phone may do
everything, via Remote Control — **proven on the user's Android phone on
2026-08-28**: `claude --remote-control` in the Nahmatik folder, `/plan-status`
answered in the Claude app). The relay user exists
(`grkmaltunbs@gmail.com`, uid `I8XBZsWr9sScTrDAiOK2LSZ5qFZ2`) and
`firestore.rules` — owner-only on that uid — is deployed to `flutterappbundle`.

## Spikes — answered 2026-08-28

1. **Spawn Remote Control without a terminal — yes, and no pty.**
   `claude remote-control --name <n> --debug-file <f>` was run with stdin
   from `/dev/null` and stdout to a file: it registered an environment,
   created a session, polled work and printed `·✔︎· Connected · nahmatik ·
   main`, the session link (`https://claude.ai/code/session_…`) and the
   environment link (`https://claude.ai/code?environment=env_…`). It found
   the login on its own. SIGTERM shuts it down cleanly and **preserves the
   environment** (`-c` / `--continue` reattaches). Two facts the host is
   built on:
   - it **refuses an untrusted folder** with `Error: Workspace not trusted.
     Please run \`claude\` in <dir> first…` — the host checks
     `~/.claude.json` → `projects[dir].hasTrustDialogAccepted` before
     spawning and says the same thing;
   - it writes `~/.claude/projects/<slug>/bridge-pointer.json`
     (`sessionId`, `environmentId`, `pid`, `procStart`) — the ids without
     parsing a TUI. The slug is the path with every non-alphanumeric
     character replaced by `-`.
   A GUI app's PATH is bare, so the host asks the login shell for the real
   one once and hands it to the child (the hooks need `dart`).
2. **Hooks → the app: a spool, not a socket.** `kit hook` reads the hook
   payload from stdin and writes one JSON file under
   `~/.flutter_kit/events/<slug>/`, named so lexical order is arrival order.
   The host watches the directory; nothing is lost when the app is closed. The
   host coalesces `PostToolUse` into the project document's `now` line (one
   write a second at most) and keeps only milestones — prompts, turn ends,
   notifications — as an `events` history.
3. **Inbox via Firestore** — `projects/{slug}/inbox/{auto}` with the board's
   batch shape; the host applies it with `applyInbox` (the same function `kit
   inbox` calls, moved into the library), stamps `appliedAt`, regenerates
   `PROJECT_PLAN.md` and the board HTML, and the plan watcher republishes the
   changed documents.
4. **Android build** — `flutter build apk --release`; see README.

## What was built (2026-08-28)

`app/` is a Flutter project (macOS + Android targets, `dev.flutterkit`), with
`../kit` as a path dependency and Firebase registered on `flutterappbundle`
(`lib/firebase_options.dart`). The macOS sandbox is off — the host spawns
`claude`, reads `~/.claude.json` and any folder the user opens; a sandboxed
child would inherit the sandbox and lose all three. This app never goes to
the Mac App Store. The kit library gained `inbox.dart`, `hook_spool.dart`
and `snapshot.dart` (56 tests); the CLI gained `kit hook`.

Screens: sign-in (the one relay user) → projects (host: folders opened;
phone: what the relay holds) → project with **Steps** (bubbles on a
pannable canvas, tap → detail panel beside it on a wide window, a sheet on a
phone), **Your work** (sittings by need, cards with runbooks, tick / not
doing / answer / note into a device-local draft, **Send to Claude** at the
bottom) and, on the host, **Session** (start/stop/reattach Remote Control,
links, trust and hook checks, what the phone sent, hook activity, process
output). The "now" line under the title is the latest hook event.

Smoke-tested over Nahmatik's real plan (73 steps, 199 items) at phone width:
every card and the code-complete step's detail render without overflow. The
one overflow it found was the same shape Nahmatik has hit four times — a
`Row` with `mainAxisSize.min` around a bare `Text` (a gate note inside a
pill); the pill's text is loose now.

## Open

- Nothing needs a decision. The phone side is verified only by the widget
  tests until the APK is installed and signed in.
- Fonts: the app uses the platform faces; `board.fonts` is not applied yet.
- Windows host: same code, untested.
