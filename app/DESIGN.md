# flutter-kit app — phase 3 design note

Written 2026-08-30 as the handoff from phase 2 ([`DESIGN-2.md`](DESIGN-2.md)).
Read this before writing any phase-3 app code. Decisions here were taken
with the user or proven by a spike today; the *Open* section is what still
needs them.

## The ask (2026-08-30)

Full control of the user's Flutter app development from this app — Nahmatik
today, every project after. Claude Code drives the plugin from the phone
(Android first, iPhone after), asks for permission and for opinions whenever
it needs them, answers a question about any one item of any step and the
app reflects what changed. Talk to Claude Code **without opening the Claude
app on the phone**, on the subscription, **no API billing**. Look and
capability in the spirit of JARVIS — an instrument, not a chat window.

## What was proven today (spikes, 2026-08-30, Claude Code 2.1.251)

| # | question | answer |
|---|---|---|
| 1 | Does headless Claude run on the subscription login? | **Yes.** `claude -p` returned a result; the stream carried `rate_limit_event { rateLimitType: five_hour, overageStatus: rejected, overageDisabledReason: org_level_disabled }` — the subscription pool, not the API. `total_cost_usd` in the result is list-price accounting (`costBasis: list`), not a charge. |
| 2 | Can a question reach the phone? | **Yes.** With `--input-format stream-json --output-format stream-json --permission-prompt-tool stdio`, `AskUserQuestion` arrives on stdout as `control_request` / `can_use_tool` (`requires_user_interaction: true`, `display_name`, `tool_use_id`, `input.questions`). Answering with `updatedInput: {…input, answers: {"Tea or coffee?": "Coffee"}}` produced the tool result *"Your questions have been answered"* and the model continued: *"You chose coffee."* |
| 3 | Can a permission prompt reach the phone, and does a denial hold? | **Yes.** Under `--permission-mode default` a `Bash` call arrived on the same channel with `permission_suggestions`, `blocked_path`, `description`. `{behavior: deny, message: "The user declined from the phone."}` — the file was not created and Claude reported the refusal. |
| 4 | Does a headless transcript resume? | **Yes.** `claude -p --resume <id> "what did I choose?"` → *"You chose coffee."* |
| 5 | Does text stream? | **Yes.** `--include-partial-messages` emits `stream_event` deltas (30 for a one-sentence reply). |
| 6 | Can the Claude app adopt the same transcript? | **Plausible, not run.** `claude remote-control --session-id <id>` exists (help text). Not run today because it registers an environment on the account. Spike 1 of phase 3. |

The stdio control protocol is what Anthropic's own Agent SDK speaks to the
CLI (`--permission-prompt-tool stdio`); it is not a documented CLI contract.
The bridge pins the CLI version it was proven on and keeps a one-file Node
sidecar on the Agent SDK as the fallback (Node 24 is on the Mac). The
runner's doc notes that since 2026-06-15 headless use on a subscription may
draw from a separate monthly *Agent SDK* allowance — verify on the plan's
usage page before relying on long unattended runs.

## Decisions taken

| decision | answer | why |
|---|---|---|
| How the phone talks to Claude without the Claude app | The host runs a **bridge**: `claude -p --input-format stream-json --output-format stream-json --include-partial-messages --replay-user-messages --permission-prompt-tool stdio --permission-mode default --session-id <uuid>` in the project folder. Phone ↔ host over Firestore; host ↔ claude over stdio. Dart, in `host/`, beside `remote_control.dart`. | Proven today, on the subscription, no second language or venv. ~400 lines. |
| Permissions and questions | Every `control_request` becomes `projects/{slug}/asks/{id}` in the relay; the phone shows it as an **authorization card** (and, when the app is closed, a notification that opens it — Allow / Deny on the notification itself comes with `notification-actions`); the answer goes back as `control_response`. A question card also takes an answer in the user's own words, beside the options — the terminal's *Other*. An ask the process leaves open when it dies or is stopped is **withdrawn** in the relay by the host (and every open ask is swept when the host comes up or a session starts), so a stale card never outlives its session on the phone. **Allow for this session** is remembered by the host for identical requests; **Always** applies the CLI's `permission_suggestions` to the project's `.claude/settings.json` and lists it on the Session screen. | Claude asks; you answer from the lock screen. Nothing runs that you did not see. |
| The Claude app stays available | **Hand over** stops the bridge and starts `remote-control --session-id` on the same transcript; **Take back** does the reverse. One driver per project at a time — the host refuses a second. | Plan mode, `/compact`, the full TUI remain one tap away, on the same conversation. |
| Asking about one item | A message carries `about: {item: id}` or `{step: id}`. The host prefixes the prompt with `kit show <id>` and a standing instruction: answer for a phone screen; if the item should change, change it with `kit` or by editing its YAML and say what changed. The plan watcher mirrors the edit; the card shows the thread and an **UPDATED** strip. Threads persist under `projects/{slug}/threads/{about}`. | Appearance is derived from data; Claude changes the data. No second state. |
| Notifications | FCM HTTP v1 **from the host**, with a service-account key at `~/.flutter_kit/flutterappbundle-service-account.json` (gitignored). The phone writes its token under `devices/{token}` after the system prompt; the host watches that list and sends one message per phone when a session raises an ask (*Allow Run? · project*, *Claude asks*, *Sign in needed* — a question whose single option is *Signed in — continue*) or hits a problem (the process died, a turn ended in an error), and when a turn ends well (*Done in 1m 25s · project* and the start of the reply) — the CLI's built-in `PushNotification` tool has no route from a bridge session (it only knows Remote Control), so the app is the route and the brief says so. Three Android channels, made in `MainActivity` — **Claude needs you**, **Problems**, **Turn ended** — so any one can be silenced alone; a `tag` per project and kind, so the newest replaces the last. A tap opens the project; in the foreground, a bar with OPEN (none for a turn that ended). **PUSH · TEST** on the Deck header sends one on request from either device. `kit notify "one line"` from the session writes a `Notify` event to the hook spool and the host pushes it as *Claude · project* — the brief says when to use it. A token FCM reports `UNREGISTERED` is dropped. The Session tab's Checks line says whether the key is there, how many phones, and the last error. | No Cloud Functions, no Blaze, no server. Allow / Deny from the lock screen itself is the next step (`notification-actions`); iOS needs an APNs key — a human item. |
| Attaching a file | The paperclip on the composer, both devices; on the Mac, a drop on the Deck too. The phone puts the bytes up in 600 KB base64 parts under `uploads/`; the host reassembles, saves under `~/.flutter_kit/attachments/`, sends images inline and every file by path, and deletes the upload. Images are shrunk on the device to the 1568-px edge the API scales to. | No Storage bucket (Blaze), no second transport. Firestore's free tier carries a screenshot in a second, and nothing stays in it. |
| Skipping permissions | A per-project option, kept in the bridge record and flipped from either device while no session runs: Start adds `--permission-mode bypassPermissions`. Questions still arrive — an `AskUserQuestion` under bypass came over stdio and its answer was read back (2026-09-03, 2.1.258). Since 2026-09-04 the switch is the **bypass** notch of the MODE dial (phase 3b); a record with `skipPermissions: true` reads as `mode: bypassPermissions`. | It is `--dangerously-skip-permissions` by another name, so it is a switch the user throws, never a default; and the phone still gets the questions, which is the half of the ask model that matters when nothing else is asked. |
| The browser | A second option: Start adds `--chrome`. Headless, the session's `init` listed `claude-in-chrome: connected` and the browser tools (navigate, find, form_input, get_page_text, computer, file_upload) on 2026-09-03; the pill shows that status while running. App Store Connect, Play Console, RevenueCat are the Mac's own logged-in Chrome tabs, driven from the phone; each browser action asks unless permissions are skipped. | The extension is on the Mac already; no Playwright profile to sign in, no second browser. |
| Model and effort | Two dials on the Deck header, both devices: `--model` by the CLI's aliases (haiku, sonnet, opus, fable) and `--effort` (low … max), `default` for the CLI's own choice. Kept in the bridge record with the two switches. All four work while a session runs: the flags belong to the process, not the conversation, so the host stops it and starts it again on the same session (`--resume`) with the new flags — at once between turns, at the end of a running turn otherwise. The facts line shows what init actually reported. | The user picks the brain and the budget per project from the phone, mid-conversation, and a wrong pick shows as a failed Start, not a silent downgrade. |
| The header folds | Start/Stop, the pills and the dials sit behind a chevron on the title row: open while idle (Start is there), folded while a session runs (the transcript is what matters), a compact Stop kept on the row, a tap overrides until the state changes. | On a phone the controls took half the screen; the conversation is the point of the screen. |
| Selecting the conversation | One `SelectionArea` over the transcript list: drag on the Mac, long-press on the phone, copy across bubbles, replies and tool rows. | A conversation you can lift out whole is a conversation you can paste into an issue. |
| What every session is told | `--append-system-prompt` at Start (honoured in stream mode, proven 2026-09-03): the user is on a phone; the browser, when Drive Chrome is on, is the Mac's own signed-in Chrome; a sign-in, second factor, captcha or payment confirmation becomes an `AskUserQuestion` with one option, *Signed in — continue* — the user reaches the Mac over Chrome Remote Desktop, signs in, answers, and the session looks again; anything a store cannot undo is asked about first. The Session tab shows the text. | Credentials stay with the human and never in a prompt. A sign-in request is an ask, so it takes the road every ask takes — the card now, the lock screen after `notifications`. |
| Voice | On-device only: `speech_to_text` on the composer mic, `flutter_tts` reads Claude's reply when the toggle is on. | The JARVIS half that costs nothing. Optional; ships after the deck works. |
| The phone is a shell on the Mac | `local_auth` (biometric) before Start, Allow, Always and Send. Owner-only rules stay; the APK is never shared. | A lost, unlocked phone must not be a terminal. |
| Look | **Instrument** — deep blue-black ground, one cyan for the system, one amber for anything that waits on you; Rajdhani headings, JetBrains Mono readouts, IBM Plex Sans prose. Canvas with the three screens and two alternates: https://claude.ai/code/artifact/b8bc9970-7ad2-4e99-987d-2f8dd146464d | An original design in the spirit of a HUD, not the film's graphics. `KitTokens` grows the second accent; `board.colors` still overrides per project. |
| iPhone | After Android, same code. Dev-profile install with the team (`8J4ASHVDQ5`); APNs for pushes. | The user's second phone; nothing in the code is Android-only. |
| Dogfood | The roadmap below becomes `plan/` at the repo root; `/step` builds this app; the human items (service account, APNs key, direction sign-off, name) are `items/`. | The plugin's own claim is that the plan is data. The app should be built by it and visible in it. |

## Architecture

```
┌──────────── macOS app (host) ─────────────────────────────────────┐
│ plan/ of every opened project, watched · kit as a library           │
│ bridge: `claude -p … --permission-prompt-tool stdio` per project    │
│   stdin  ← user messages, control_responses                        │
│   stdout → assistant text (streamed), tool rows, control_requests, │
│            result                                                   │
│ asks: control_request → relay asks/{id} → phone → control_response │
│ remote control: hand over / take back on the same session id       │
│ hooks spool → "now" line + events (unchanged from phase 2)         │
│ inbox batches applied with applyInbox (unchanged)                   │
│ FCM v1 sender (service account) → the phone                         │
└───────────────┬────────────────────────────────────────────────────┘
                │ Firestore (flutterappbundle), owner-only
                │ projects/{slug}: snapshot · chat · asks · threads · commands
┌───────────────┴────────────────────────────────────────────────────┐
│ phone (Android, then iPhone)                                        │
│ Command deck: talk to the session, see it work, answer its asks     │
│ Steps: the constellation · Your work: sittings, cards, threads      │
│ Session: start / stop / hand over · notifications with actions      │
└────────────────────────────────────────────────────────────────────┘
```

## The bridge protocol (the contract the host is built on)

What the host writes to stdin:

```json
{"type":"user","message":{"role":"user","content":"/step"}}
{"type":"control_response","response":{"subtype":"success","request_id":"<id>","response":{"behavior":"allow","updatedInput":{"…":"…"}}}}
{"type":"control_response","response":{"subtype":"success","request_id":"<id>","response":{"behavior":"deny","message":"The user declined from the phone."}}}
{"type":"user","message":{"role":"user","content":[{"type":"image","source":{"type":"base64","media_type":"image/png","data":"…"}},{"type":"text","text":"What is wrong on this screen?\n\n--- attached … ---"}]}}
```

The third line is a message with files: an image the API takes (png,
jpeg, gif, webp, ≤ 4 MB) rides inline as a block — proven 2026-09-02 on
2.1.258, a red square went in and `Red` came back — and every file, image
or not, is saved under `~/.flutter_kit/attachments/<project>/` and named by
path in a trailer, for the Read tool.

What the host reads from stdout, one JSON object per line:

| `type` | what the host does |
|---|---|
| `system` / `init` | records `session_id`, model, permission mode → `session` on the project doc |
| `stream_event` | appends text deltas to the open assistant message in `chat/` (coalesced, ≤ 1 write/s) |
| `assistant` | final content: text → the message; `tool_use` → a compact tool row; `usage` → the context arc (the three input fields summed are what the call read) |
| `user` (tool_result) | closes the tool row with its result summary |
| `control_request` / `can_use_tool` | writes `asks/{request_id}`; `AskUserQuestion` renders as a question card, anything else as an authorization card; waits for the answer |
| `result` | closes the turn; `chat` gets the summary; `session.state = idle` |
| `rate_limit_event` | the pool arc: `unifiedWindows.five_hour` and `seven_day` carry a utilization and a reset each (2.1.261); `status: rejected` is the exhausted line |
| `system` / `compact_boundary` | the conversation was compacted: `compact_metadata.pre_tokens` → `post_tokens`; the arc drops, a note row says so |

A `control_request` is answered by whichever surface answers first — the
Mac window, the phone card, or a notification action — and the others
collapse. The host answers on its own only for a request identical to one
the user allowed "for this session".

## Firestore shape (additions to phase 2)

```
projects/{slug}.session               {mode: bridge|remote|idle, sessionId, model, startedAt, pool{status, resetsAt, fiveHour{utilization, resetsAt}, sevenDay{…}}, context{used, window, at}, compacting, skipPermissions, chrome, chromeStatus?}
projects/{slug}/chat/{auto}           {role: user|assistant|tool, text, about?, tool?, status?, at}
projects/{slug}/asks/{requestId}      {kind: permission|question, tool, input, suggestions, description, at, answer?, answeredAt?, by?}
projects/{slug}/threads/{about}/messages/{auto}   the per-item / per-step conversation
projects/{slug}/commands/{auto}       phone → host: {type: start|stop|send|options|handover|answer, payload, uploads?, at, doneAt?}
(uploads rode Firestore in 600 KB base64 parts until step 10, 2026-09-04; now an object in Storage under projects/{slug}/uploads/{id}/{name}, named by the send command — see Phase 3b)
```

The phone never writes `chat` or `asks` directly — it writes `commands`
(and `uploads`, which the host consumes); the host is the only writer of
session truth, as in phase 2.

## Roadmap — as steps, each gated on running

| # | step | done when | needs you |
|---|---|---|---|
| 0 | `dogfood-plan` | `plan/` exists at the repo root with these steps and items; `/step` picks step 1 | name the app; pick the lead direction |
| 1 | `bridge-core` | From the Mac window: Start → `/plan-status` → the answer streams into the deck; a permission renders as an ask card and Allow / Deny round-trip (a session hangs on an unanswered ask, so the card is part of the bridge); Stop ends the process; a host restart finds the session by id | — |
| 2 | `asks` | Asks mirrored to the phone and answered there; "This session" remembered by the host; "Always" applies `permission_suggestions` and the Session tab lists it | — |
| 3 | `deck-on-the-phone` | The Command deck on Android: send, stream, answer an ask, quick chips, switch project | — |
| 4 | `instrument-skin` | Tokens, fonts, the constellation, restyled cards and sheets; overflow matrix at 1.0 / 2.0 / 3.12 | sign off the canvas |
| 5 | `item-threads` | Ask on any card or step → a scoped answer; an item Claude edits updates on the phone within seconds; the UPDATED strip | — |
| 6 | `notifications` | An ask, a sign-in or a problem reaches the phone as a notification while the app is closed; a tap opens the project | a service-account key on the Mac |
| 6b | `notification-actions` | Allow / Deny on the notification itself, from the lock screen, without opening the app | — |
| 7 | `handover` | Hand over → the Claude app shows the same conversation; Take back → the deck continues it; a second driver is refused | run spike 6 |
| 8 | `voice-and-biometrics` | Dictate a message; hear the reply; biometric gate on Start / Allow / Send | — |
| 9 | `iphone` | The app on the user's iPhone with pushes | APNs key; register the device |

Steps 1–3 are the spine; nothing in 4–9 is worth building until a `/step`
has been driven from the phone with an ask answered on it.

## Open — needs you

- **A name.** `kit_app` is the scaffold's. The deck, the constellation and
  the notification channel will carry it.
- **Lead direction** on the canvas: Instrument (lead), Workshop, or Daylight
  — or Instrument as dark mode with Daylight as light.
- **Voice** in scope now, or after iPhone.
- **Always allow from the phone** may write `permission_suggestions` into the
  project's `.claude/settings.json`. Recommended yes, with the list visible on
  the Session screen and removable there.
- **Headless accounting** on the subscription — confirm on the plan's usage
  page (see the runner note) before the first unattended run.

## Risks, and what holds them

- *The control protocol changes.* Pin the CLI version in the host; on a
  parse failure the Session screen says so and offers hand-over to the
  Claude app, which needs none of it. Fallback: the Agent SDK sidecar.
- *Two Claudes in one tree.* One driver per project, enforced by the host
  from the bridge pointer and the process table, as phase 2 already does for
  Remote Control.
- *The phone as a terminal.* Biometrics on the dangerous taps, owner-only
  rules, a never-shared APK, and every command visible in the transcript.
- *Headless loses the TUI.* Model is a start option; `/compact` as a message
  is a spike; plan mode is `--permission-mode plan` on start. Everything
  else is one hand-over away.

## Phase 3b — everything the agent can do (2026-09-04)

The ask, 2026-09-04: *"the app, using the MacBook, should do everything
that an AI agent can do"* — for rapid app development. Phase 3's spine
(bridge, asks, deck, threads, attachments, options, dials, notifications)
is a phone-side terminal for Claude. What the phone still could not do:
see the app under test, read the diff, touch the repo, approve a plan, or
keep the agent going without a person. The user took the whole list on
2026-09-04; the steps are `plan/steps/` 10–28 and `kit status` is the
order. This section records the decisions the steps are built on.

### Decisions taken

| decision | answer | why |
|---|---|---|
| Bytes that are not rows | **Firebase Storage** on the relay, owner-only rules, the client SDK on both roles (both are signed in as the relay user — no key). Uploads, mirror frames, builds, push images, big files. The 600 KB base64 parts in Firestore go. | One transport unlocks four steps; Blaze is on already. |
| The host when nobody is at the Mac | A **service**: start at login, a power assertion (`caffeinate -is -w <pid>`) while anything runs, a `hosts/{id}` heartbeat every 30 s so the phone says *unreachable since* instead of hanging. | A closed lid or a reboot is how sessions die today. Lid-close sleep is not preventable; the `lid-closed-sleep` item says so. Built 2026-09-04 as a LaunchAgent (`~/Library/LaunchAgents/dev.flutterkit.kitApp.plist`, RunAtLoad, KeepAlive on an unclean exit only) written but not bootstrapped on enable — bootstrapping would start a second copy beside the running one; it takes effect at the next login. |
| Permission mode | A **MODE dial** — default · plan · accept edits · bypass — replaces the Skip permissions pill. `ExitPlanMode` arrives on the ask channel with the plan in its input and renders as a **plan card**: Approve (edits ask) · Approve, auto edits · Revise (words the session reads, then plans again). Built 2026-09-04: the dial switches a running session in place with `set_permission_mode` — at once between turns, at the turn's end otherwise — and follows an answer that carries a `setMode` (a plan approved, "allow all edits" on an edit), which the CLI applies without an event. The facts line shows the mode the CLI last reported. | Reading and approving the plan from the phone is the most agent-like thing that was missing. |
| Stopping a turn | An **interrupt** control request on stdin — `{"type":"control_request","request_id":…,"request":{"subtype":"interrupt"}}` — ends the turn and keeps the session (proven 2026-09-04, below). INTERRUPT sits on the Deck's title row while a turn runs; Stop waits in the fold. An ask open when the turn is cut is withdrawn with it; the cut turn's row says "Interrupted from the phone"; no Done push for it. Messages sent mid-turn are **queued** by the host — the row says so, WITHDRAW takes it back, and the first in line goes the moment the `result` lands. `set_permission_mode` and `set_model` are both honoured, so the MODE and MODEL dials switch in place; only Chrome and effort still restart on `--resume`. | Stop kills the process; the SDK has a brake that does not. |
| Reviewing the agent | **Diffs on Edit/Write asks** (host-computed, ≤ 24 KB), any path a tap to a **file view**, a **Git card** (branch, dirty, last commit; Commit / Push / Revert file) the host runs directly. Built 2026-09-06: the diff is `kit/lib/src/diff.dart` (prefix/suffix trim, then an LCS over what is left when it is under 1500×1500 lines, else a whole replacement); the bridge computes it when the tool call streams in — before the tool runs, so the file is still as it was — and the ask for the same `tool_use_id` reuses it. The tool row of an edit that ran shows the same diff on tap. A file read is a `host` command answered in `files/{commandId}` (the first 200 KB inline, the whole file in Storage past that; refused outside the project and its attachments, or for a folder, a binary, or past 8 MB). git runs where the host is, with no model; each command becomes a tool-style row and a line the next prompt opens with ("Since your last turn the user did this from the app…"), so the session never works from a picture that is out of date. | The human half of an agent is reading what it changed. |
| Actions that need no model | **`host` commands** — `{type: host, action: read_file|git|blocks|step_done|reorder|…}` — the host runs the kit library, git or the toolchain and answers in the relay; no quota. Everything on the Git card, the constellation's controls, the run bay and the mirror are host commands. | Half of what the phone asks Claude today is a shell command. The app must stay useful with the pool empty. |
| Instruments | Two arcs on the Deck's facts row, both devices: the **context** each assistant message's `usage` reports (input + cache creation + cache read) against the model's window (the `result`'s `modelUsage[model].contextWindow` — 1,000,000 for `claude-fable-5-1` on 2.1.261 — else 1M for `[1m]` and Fable, 200k otherwise), amber past 70 %, red past 85 %; the **five-hour pool** from `rate_limit_event`'s `unifiedWindows`, the countdown to its reset under it, the weekly window in the sheet a tap opens and on the Session screen. **COMPACT** past 80 %: `/compact` as a message compacts in `-p` (spike answered 2026-09-06, below); the arc drops and a row says "Compacted · 80.6K → 3.6K tokens". A turn's cost rides on its last row (`24.4K CTX · 3.7K OUT`). Tokens, never dollars. Built 2026-09-06. | The JARVIS reading: the state of the machine at a glance. |
| Keeping the agent going | **Autopilot** in the host: `/step` after each passed step, within a budget; stops on an ask, a second failed gate, the human's move; **night shift** waits out the pool from the event's reset time. Replaces `runner/`, which is deleted in that step. | The runner was parked and unwireable; the bridge makes the loop a hundred lines. |
| The app under test | The host owns the process: **run bay** — `flutter run -d <device> --machine --print-dtd`, the daemon protocol (`app.restart`, `app.stop`, `app.debugPort`), the log tail in the relay, the VM/DTD URIs in the brief for the Dart MCP server. **Mirror**: frames through Storage, taps back through `adb shell input` / `idb ui`. **Try it**: a debug APK built by the host, installed from a push; share-sheet intake. | "Does it run" becomes something you watch, then something you hold. |
| Pushes on Android (step 6b, built 2026-09-04) | A **data message**, not a tray notification: the phone draws it with `flutter_local_notifications` on the same four channels (`asks`, `problems`, `done`, `steps`), with **Allow / Deny** — or a short single question's options, or a sign-in's one option — as buttons. A button runs in a background isolate: it reads the ask from the relay, writes the `answer` command the card would, and takes the notification down; a failure replaces the buttons with a line. An ask answered anywhere makes the host send a silent **withdraw** message so the notification comes off every phone. Other platforms still get FCM's tray notification. | Buttons on a notification need the app to draw it; the withdraw keeps a stale Allow off the lock screen. |
| Hand-over to the Claude app | **Parked** last (step 28, rank 2000). | With the dial, the plan card, interrupt, compaction and history in the bridge, nothing remains that only the Claude app can do; it registers an environment on the account for a spike with an unknown answer. Kept as the fallback if the protocol breaks. |
| Voice | Narrowed: read the ask and the finished summary aloud, answer an ask by voice; never the streamed reply. Biometrics widened to bypass, Autopilot, Revert, Merge, Remove; a kill switch. After the agent-parity steps, before the iPhone. | Resolves `voice-now-or-later`: later, and less. |
| The Mac window | The host's console, not a second product: every host feature has a Mac control for QA, but phone-only polish (crew strip, since-you-looked, share intake, install) is not mirrored there. | The phone is the product; the Mac is the engine. |
| Focus on the phone | The Deck is **one scroll**: the ask card is the last row of the transcript (a plan card renders whole, no box of its own), and the composer alone keeps the bottom. A drag upward (reading down) folds the chrome — the tab strip, the NOW strip, and the header to one row with the status, the title and Stop; a drag downward, or the row's chevron, brings it back. The Mac never folds. Built 2026-09-04 from the user's QA of plan-mode: three stacked scrollables hid the last rows behind a tall plan card. | Most of a phone's screen for the conversation, and nothing lost — the status stays on the row. |

### Protocol additions (stdin, client → CLI)

```json
{"type":"control_request","request_id":"<uuid>","request":{"subtype":"interrupt"}}                            // proven 2026-09-04
{"type":"control_request","request_id":"<uuid>","request":{"subtype":"set_model","model":"opus"}}                  // proven 2026-09-04
{"type":"control_request","request_id":"<uuid>","request":{"subtype":"set_permission_mode","mode":"plan"}}       // proven 2026-09-04
```

`interrupt` (2.1.260): the CLI answers at once with
`{"type":"control_response","response":{"subtype":"success","request_id":…,"response":{"still_queued":[]}}}`,
echoes a user line `[Request interrupted by user]`, and ends the turn
with a `result` (`stop_reason: null`). Cut while counting at 57, asked
"what was the last number?", the session answered 57 — the conversation
is intact. `still_queued` says the CLI has a queue of its own for user
messages that arrive mid-turn; the host keeps its own anyway, so a
queued message shows on the phone and can be withdrawn.

`set_model` (2.1.260): a bare success
`{"subtype":"success","request_id":…}`, a replayed user line
`<local-command-stdout>Set model to \`haiku (claude-haiku-4-5-20251001)\`</local-command-stdout>`
(`isReplay: true`), and a fresh `init` naming the model; the next
`assistant` message carries it. `default` resolves to the CLI's own
choice (`claude-opus-5[1m]` that day). No `set_effort` exists; effort
still restarts the process.

`set_permission_mode` (2.1.260): the CLI answers
`{"type":"control_response","response":{"subtype":"success","request_id":…,"response":{"mode":"plan"}}}`,
then writes `{"type":"system","subtype":"status","status":null,"permissionMode":"plan"}`
and a fresh `system/init` naming the mode. The session, its transcript
and its context are untouched; the next turn runs under the new mode
(an `Edit` under `default` asked, under `acceptEdits` it ran). The host
reads the `status` into the transcript and logs a refused response.

And on stdout, two things the host now reads that it ignored: `usage` on
every `assistant` message (the context gauge) and `parent_tool_use_id`
on messages a subagent produced (the crew strip). One thing it learned
the hard way (2026-09-04): with `--input-format stream-json` the CLI
writes **nothing** at spawn — its `system/init` line comes with the first
user message. A process still alive 1.5 s after Start is therefore
*ready*, not *starting*, and nothing may wait on the init before the
first send. The CLI also writes a session to `~/.claude/projects/` only
on its first turn, so `--resume` of one that never spoke fails with "No
conversation found" — the bridge starts fresh instead.

`ExitPlanMode` (proven 2026-09-04, 2.1.260) is a `can_use_tool` request
with `requires_user_interaction: true` and no `permission_suggestions`;
its `input` is `{plan: <markdown>, planFilePath: ~/.claude/plans/<slug>.md}`.
Under `--permission-mode plan` the CLI writes that plan file itself
without asking. The allow response takes a mode:
`updatedPermissions: [{type: setMode, mode: acceptEdits|default, destination: session}]`
switches the session at once and silently — no `status`, no `init`; the
tool result reads *"User has approved your plan. You can now start
coding"* and the next `Write` ran without asking under `acceptEdits`. An
allow without a `setMode` lands on `default` (the next `Edit` asked). A
deny with a message keeps plan mode; the session reads the message and
plans again. An `Edit` ask's `permission_suggestions` carry the same
`setMode acceptEdits` — Always on an edit is a session mode, not a rule
in a settings file, and the dial follows it.

`/compact` as a user message (proven 2026-09-06, 2.1.261) compacts in
`-p`. The CLI writes `system/status {status: compacting}` (again every
30 s), then `status {status: null, compact_result: success}`, a fresh
`init`, `system/compact_boundary {compact_metadata: {trigger: manual,
pre_tokens: 80559, post_tokens: 3596, duration_ms: 37920, …}}`, two
replayed user lines (the summary itself, and
`<local-command-stdout>Compacted </local-command-stdout>`), and a
`result` with `num_turns: 0` and zero usage. 38 s for 81K. The next call
read 22K (the summary under the system prompt and the tools), so the arc
drops to `post_tokens` at the boundary and corrects itself on the next
message. Every `assistant` message's `usage` is the call's own —
`input_tokens + cache_creation_input_tokens + cache_read_input_tokens` is
what the model read — and the `result`'s `usage` is the turn's total, its
`modelUsage` naming each model's `contextWindow`.

### Relay shape (additions to phase 3)

```
projects/{slug}/files/{commandId}     the host's answer to a read_file: {path, text, lines, bytes, truncated, blob?, refused?}; the phone deletes it once read
projects/{slug}/commands/{auto}       … {type: host, action: read_file, path} | {type: host, action: git, op: commit|push|revert, message?, path?}
projects/{slug}                       session.git = {branch, ahead, behind, dirty, lastCommit, error?, at}
hosts/{hostId}                        {seenAt, name, appVersion, cli, projects: [slug], stopping?}
projects/{slug}.run                   {device, appId, state, since, vmUri, dtdUri}
projects/{slug}.mirror                {seq, at, w, h, watching?}
projects/{slug}.session.context       {used, window, at}   (built 2026-09-06, with session.pool and session.compacting)
projects/{slug}.autopilot             {on, budget, done, nightShift, waitingUntil?, stoppedFor?}
projects/{slug}/sessions/{id}         {startedAt, endedAt, firstMessage, turns, model, mode}
projects/{slug}/runs/{id}/log/{n}     lines, coalesced ≤ 1 write/s, last 2000 kept
projects/{slug}/files/{id}            {path, text, lines, truncated}  (text in Storage past 900 KB)
projects/{slug}/builds/{id}           {sha, branch, version, size, at, path}
projects/{slug}/commands/{auto}       + {type: host|input, action, …}
projects/{slug}/chat/{auto}           + sessionId, parentToolUseId?, diff?
projects/{slug}/asks/{id}             + diff?, plan?
devices/{token}                       + quiet: {from, to, zone}
```

Storage, owner-only:

```
projects/{slug}/uploads/{id}/{name}   projects/{slug}/frames/live.jpg   projects/{slug}/builds/{sha}.apk
projects/{slug}/shots/{id}.jpg        projects/{slug}/files/{id}
```

The phone still never writes `chat` or `asks`; it writes `commands` and
puts objects in Storage. The host is the only writer of session truth.

### Spikes to run first, each recorded here when answered

1. `interrupt` on the pinned CLI: **answered** 2026-09-04 (above) — `{still_queued: []}`, an echoed user line, a `result`; the session lives.
2. `set_model` / `set_permission_mode`: **both honoured** (2026-09-04, above); the dials switch in place.
3. `ExitPlanMode`'s request: **answered** 2026-09-04 (above) — `input.plan`, and the allow takes `setMode`.
4. `/compact` as a user message in `-p`: **compacts** (2026-09-06, above) — `status compacting`, a `compact_boundary` with the tokens before and after, a fresh `init`, a `result` with no turns.
5. `xcrun simctl io <udid> screenshot` to a pipe, and the frame rate it sustains.
6. The CLI's transcript file under `~/.claude/projects/<cwd-key>/` for session history.

### Risks, and what holds them

- *More undocumented protocol.* Every new request is behind a spike and a
  fallback that already works (restart on `--resume`, Stop, a fresh
  session). The pin on the CLI version stays.
- *The phone as a shell, wider.* Revert, Merge, Remove, bypass, Autopilot
  and the kill switch sit behind the biometric gate from step 26; until
  then each has a confirm sheet. The host reads and writes files only
  inside the project folder and its attachments folder.
- *Autopilot loops.* The loop stops on an ask, on a second failed gate, on
  the human's move, on the budget, on Stop; every start and stop pushes.
  The accounting item blocks the step until the plan's usage page has
  been read.
- *Storage cost.* Frames at one a second only while a sheet is open and a
  phone heartbeat says so; three builds kept; uploads deleted on save.
