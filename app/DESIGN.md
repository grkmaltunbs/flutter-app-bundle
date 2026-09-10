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
| Deck crew | **Crew.** An `Agent` tool use (the CLI's name for its subagent tool on 2.1.261; `Task` in its tools list) is a chip on a strip under the header — kind and description, a pulse and a running clock, dim with its time once done; every message the subagent produces carries `parent_tool_use_id` and folds under the chip, so the main list stays the user's conversation. The CLI narrates the subagent as `system/task_started`, `task_progress` (tool uses, tokens, last tool) and `task_notification` (status, summary); the Agent row keeps that as `progress`, and its `tool_result` is the report. **Tool rows that open.** Every tool row is a tap: the whole input (the command, or indented JSON) and the result up to 24 KB, "the rest is on the Mac" past that, the diff and the file behind a path where there is one. **Since you last looked.** The phone remembers `<session id>:<row id>` of the newest row shown with the app in front (per project, on the device); the next open draws one line above the first row after it and lands there; another session means every row is new. Built 2026-09-06. | The Deck reads like a conversation with one agent, whatever runs underneath — and picks up where the eyes left it. |
| Keeping the agent going | **Autopilot** in the host: `/step` after `/step` within a budget of sends (1–10), and stops for you. Built 2026-09-06 (`app/lib/src/host/autopilot.dart` over the pure decisions in `kit/lib/src/autopilot.dart`): on the `result` of a turn it started — the transcript now records which user row's turn a result ended (`lastTurnRowId`), so a `/step` queued behind the person's own message is not confused with it — the host re-reads `plan/` from disk and sends the next `/step` (the active step, else the first ready one: `kit next --step`), or stops with the reason: the budget; a step that added two failed gates to its history; a plan where the human moves next (an open item gates every pending step — named in the line); an error; Stop, INTERRUPT or the process ending. An ask never stops it: the turn waits, so the loop does. The pool refusing (`rate_limit_event` `rejected` before the `result`) stops it too — unless **night shift** is on, which waits until the window's reset plus a minute, resumes the session on the same id if the process died meanwhile, and sends the same `/step` again (that send counted nothing). The refused-pool path is proven against a scripted event only; the live shape is assumed to be the event then an error `result`. Every start, every step that finished (flipped, or built and waiting on a person) and every stop is one line on the Turn ended channel — `Autopilot · <project>`, then `Step 12 done · 2 of 5`, `Stopped · needs you: Register the iPhone` — and a note row in the transcript; the loop's `/step` rows carry `by: autopilot` and read AUTOPILOT. The plain Done push is held for a turn the loop drove. Toggle: an AUTOPILOT pill in the Deck's fold on both devices — off, a tap opens the budget sheet (steps, night shift, the fixed rules, START as the confirm); on, a tap stops it — and one line under the facts while it runs (`AUTOPILOT · STEP 12 · 2 OF 5`, `· NEEDS YOU` on an ask, `WAITING FOR THE POOL · 0:42:10` counting down), kept on the folded row. `runner/` was deleted with it. Found on the first live run (2026-09-06): the bridge flushed stdin after every line, unawaited, and Dart's IOSink is *bound* while a flush is pending — the loop's `/step` written right after a `set_permission_mode` at the same turn's end threw "StreamSink is bound to a stream" and never reached the CLI. The bridge no longer flushes; one `_write` helper logs a failed write instead of dropping the turn on the floor. **A clean context per step** (added the same day, at the user's question): every `/step` after the first is preceded by `/clear` — the plan on disk is the memory, and a step never needs the last one's conversation; the context arc drops to nothing and the transcript says "Context cleared." (`/clear` proven headless, below). | The runner was parked and unwireable; the bridge makes the loop a hundred lines. |
| The app under test | The host owns the process: **run bay** — `flutter run -d <device> --machine --print-dtd`, the daemon protocol (`app.restart`, `app.stop`, `app.debugPort`), the log tail in the relay, the VM/DTD URIs in the brief for the Dart MCP server. Built 2026-09-06 (`app/lib/src/host/run_bay.dart` over the pure `kit/lib/src/run.dart`): a RUN card in the Deck's fold on both devices and on the Session tab — the device picker (`flutter devices --machine`, plus the emulators `flutter emulators` lists that are off, one per kind; the plan's `qa.runtime` picks the default; an off pick is booted with `flutter emulators --launch` and polled for), RUN · RELOAD · RESTART · STOP, LOG, and a reload-on-edit switch (a watch on `lib/`, one reload per burst of saves). The run rides on `session.run` and one line under the facts (`RUNNING · IPHONE 17 PRO · 4 MIN`, amber with the count once a line reads like an exception; a tap opens the log). The log is the last 2000 lines in documents of 200 under `runs/{id}/log/`, one write a second at most; the sheet follows, pauses, finds and copies. The session hears about a run as a host note on its next prompt (the URIs, "the host owns the process") and every Start's brief carries the bay's state, so the Dart MCP server reaches the same app. Proven on the daemon (0.6.1, below). **Mirror**: frames through Storage, taps back through `adb shell input` / `idb ui`. Built 2026-09-06 (`app/lib/src/host/mirror.dart` over the pure `kit/lib/src/mirror.dart`): a frame is `xcrun simctl io <udid> screenshot` (a quarter second), `adb exec-out screencap -p` or `screencapture -R` of the app's window (its bounds from System Events by the pubspec's name), shrunk with `sips -Z 720` to a ~40 KB JPEG at `projects/{slug}/frames/live.jpg`; the project document's `mirror` carries `{seq, at, w, h, dw, dh, streaming, lastInput, error}` from the host and `{watching: {at, by}}` from the phone (both merge). One frame from MIRROR on the RUN card; one a second while a sheet's heartbeat (every 5 s) is younger than 15 s and the app runs — a sheet left open on a locked phone goes quiet and the stream stops. The sheet draws the frame at its aspect with the age, turns a tap or a drag into `{type: input, action: tap|swipe|text|key, x, y, x2, y2, text}` in the device's own pixels (from the drawn size and `dw`×`dh`), and the host plays it — `adb shell input` on Android, `idb ui` on the simulator with pixels turned into points by `SIMULATOR_MAINSCREEN_SCALE`, a refusal on macOS — then takes the next frame at once. Without idb the line says so and input waits. The camera icon hands the frame to the composer as `frame-<seq>.jpg`, the way the paperclip does. QA 2026-09-06 over the relay (the phone was off USB): 49 frames in the 15 s a heartbeat lasts, a refused tap on the simulator (no idb), and on the Android emulator — booted by the bay from its off entry — a tap through adb that hit the counter's button and a swipe. One thing learned: a Firebase Storage *download URL* token dies with every overwrite, so a frame a second is unreadable by URL; the phone reads the object through the SDK, which is why the sheet never uses URLs. **Try it**: a debug APK built by the host, installed from a push; share-sheet intake. Built 2026-09-06 (`app/lib/src/host/builds.dart` over the pure `kit/lib/src/builds.dart`): TRY IT on a Builds card in the fold of both devices and on the Session tab — the host runs `flutter build apk --debug --target-platform android-arm64` in the project (a fat debug APK of the scratch app was 176 MB; arm64 alone is a third of that), puts the APK at `projects/{slug}/builds/{id}.apk`, writes `builds/{id}` `{state, sha, branch, version, size, at, path, progress, error, log, by, name}`, pushes "Build ready · <project> · <version>" (or "Build failed" with the first error line) on the done channel with the build's id in the tap, and keeps the last three, deleting older objects and documents. A **build on flip** switch per project (kept in `~/.flutter_kit/builds/`) builds on its own when a step flips to done or code complete, once per step. On the phone a ready row — or the push's tap — downloads the APK to the app's cache with progress and opens the system installer (`open_filex`, `REQUEST_INSTALL_PACKAGES`); a failed row opens its log. **Share back**: K.A.T.Y.A is a share target for images and text (`receive_sharing_intent`, `singleTask`); a share opens the Deck of the one open project — a picker when there are several — with the file on the composer and the cursor in it. QA over the relay 2026-09-06 (the phone was off USB, so install and share are widget/unit tested only): a debug APK built and reached Storage, DELETE removed one build, four builds pruned to three. Two facts learned: a debug APK is large (a fat one was 176 MB; `--target-platform android-arm64` is 146 MB — libflutter and the kernel blob dominate), and a command's own document id is injected as `id`, so the build's id must ride under a distinct key (`buildId`) or the delete hits nothing. | "Does it run" becomes something you watch, then something you hold. |
| Pushes on Android (step 6b, built 2026-09-04) | A **data message**, not a tray notification: the phone draws it with `flutter_local_notifications` on the same four channels (`asks`, `problems`, `done`, `steps`), with **Allow / Deny** — or a short single question's options, or a sign-in's one option — as buttons. A button runs in a background isolate: it reads the ask from the relay, writes the `answer` command the card would, and takes the notification down; a failure replaces the buttons with a line. An ask answered anywhere makes the host send a silent **withdraw** message so the notification comes off every phone. Other platforms still get FCM's tray notification. | Buttons on a notification need the app to draw it; the withdraw keeps a stale Allow off the lock screen. |
| Hand-over to the Claude app | **Parked** last (step 28, rank 2000). | With the dial, the plan card, interrupt, compaction and history in the bridge, nothing remains that only the Claude app can do; it registers an environment on the account for a spike with an unknown answer. Kept as the fallback if the protocol breaks. |
| Voice | Narrowed: read the ask and the finished summary aloud, answer an ask by voice; never the streamed reply. Biometrics widened to bypass, Autopilot, Revert, Merge, Remove; a kill switch. After the agent-parity steps, before the iPhone. | Resolves `voice-now-or-later`: later, and less. |
| The Mac window | The host's console, not a second product: every host feature has a Mac control for QA, but phone-only polish (crew strip, since-you-looked, share intake, install) is not mirrored there. | The phone is the product; the Mac is the engine. |
| Focus on the phone | The Deck is **one scroll**: the ask card is the last row of the transcript (a plan card renders whole, no box of its own), and the composer alone keeps the bottom. A drag upward (reading down) folds the chrome — the tab strip, the NOW strip, and the header to one row with the status, the title and Stop; a drag downward, or the row's chevron, brings it back. The Mac never folds. Built 2026-09-04 from the user's QA of plan-mode: three stacked scrollables hid the last rows behind a tall plan card. Redone 2026-09-06 at the user's word — the fold snapped on the first few pixels of a drag and cut the drag short. The chrome now lies *over* the list, which keeps a top inset the size of the whole chrome, and a finger on the list folds it by the pixel: every drag delta (and, at the list's end, the overscroll) moves the fold, so the rows slide up under the chrome in step with the finger, a drag the other way grows it back from anywhere in the list, and the list — which never changes height — never jumps. A fling and the host's own jump to the newest row leave the fold alone; the chevron animates it. The whole chrome is clipped from the bottom as it folds and crosses over to the one row in the last stretch; its two heights are measured after each frame. A `NestedScrollView` with a floating sliver was tried first and dropped: its controllers speak a combined offset, so the Deck opened folded whenever rows arrived and the chevron would have scrolled the list to the top. The Mac keeps its plain header. | Most of a phone's screen for the conversation, and nothing lost — the status stays on the row. |

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

`/clear` as a user message (proven 2026-09-06, 2.1.261) empties the
context in `-p`: the CLI writes `{"type":"conversation_reset"}`, runs the
SessionStart hook again (`hook_started`/`hook_response`), a fresh `init`,
and a `result` with `num_turns: 0` — no model call, no quota. The next
turn knew nothing of the word it had been asked to remember. The bridge
reads the reset into the transcript as "Context cleared." and drops the
context reading to nothing.

`flutter run --machine --print-dtd` (proven 2026-09-06, daemon 0.6.1):
stdout carries the daemon's JSON lines *and* the tool's plain lines
("Launching lib/main.dart on macOS in debug mode...", "✓ Built …",
"Reloaded 0 libraries in 106ms", "Application finished."); stderr the
toolchain's warnings. The events, in order: `daemon.connected {version,
pid}`, `app.start {appId, deviceId, directory, supportsRestart, launchMode,
mode}`, `app.progress {appId, id, progressId, message?, finished}`,
`app.debugPort {appId, port, wsUri, baseUri}`, `app.devTools {appId, uri}`,
`app.dtd {appId, uri}` (that is where `--print-dtd` lands in machine
mode), `app.started {appId}`. Commands go as
`[{"id":1,"method":"app.restart","params":{"appId":…,"fullRestart":false,"reason":"manual"}}]`
and answer `[{"id":1,"result":{"code":0,"message":"Reloaded 0 libraries"}}]`;
`app.stop` answers `{"id":3,"result":true}` and the process ends after
"Application finished." — no `app.stop` event came. No `app.log` event
came on macOS either: the app's own output is plain lines.
Two things the phone QA taught (2026-09-06, iPhone 17 Pro simulator):
the app's `print`s reach the daemon as plain `flutter: …` lines and an
unhandled exception as `[ERROR:flutter/runtime/dart_vm_initializer.cc(40)]
Unhandled Exception: …` — the log counts those; but an exception thrown
in `build` never reaches stdout at all: with the inspector's structured
errors on, the framework hands it to the error stream, and only a
session on the VM service sees it. And the Dart MCP server is configured
per project in `~/.claude.json` (Nahmatik has it; a fresh folder does
not) — without it the session still read the error history over the VM
service socket the brief named, and started no second `flutter run`.

A subagent (proven 2026-09-06, 2.1.261): the model calls a tool named
`Agent` with `{subagent_type, model, description, prompt}` — the init's
tools list still says `Task`. The CLI then writes `system/task_started
{task_id, tool_use_id, description, subagent_type, is_backgrounded,
prompt}`, a `user` line carrying the prompt with
`parent_tool_use_id: <the Agent's tool_use_id>`, the subagent's own
`assistant` tool uses and `user` tool results with the same parent,
`system/task_progress {tool_use_id, description, usage: {total_tokens,
tool_uses, duration_ms}, last_tool_name}` as it goes, then
`system/task_updated {patch: {status: completed}}`,
`system/task_notification {tool_use_id, status, summary, output_file,
usage}`, and at last the parent's own `user` tool result for the Agent
call (the report) with no parent. No text deltas arrived with a parent:
a subagent's words come whole. `stream_event` lines for the parent carry
`parent_tool_use_id: null`.

### Relay shape (additions to phase 3)

```
projects/{slug}/files/{commandId}     the host's answer to a read_file: {path, text, lines, bytes, truncated, blob?, refused?}; the phone deletes it once read
projects/{slug}/commands/{auto}       … {type: host, action: read_file, path} | {type: host, action: git, op: commit|push|revert, message?, path?}
projects/{slug}                       session.git = {branch, ahead, behind, dirty, lastCommit, error?, at}
hosts/{hostId}                        {seenAt, name, appVersion, cli, projects: [slug], stopping?}
projects/{slug}.session.run           {phase, runId, device, deviceName, appId, since, vmUri, dtdUri, error, exceptions, lastError, lines, reloadOnEdit, devices[], devicesAt}   (built 2026-09-06)
projects/{slug}/commands/{auto}       + {type: run, action: start|reload|restart|stop|devices|reload_on_edit, device?, on?}
projects/{slug}.mirror                {seq, at, w, h, dw, dh, streaming, lastInput, error} + {watching: {at, by}} from the phone   (built 2026-09-06)
projects/{slug}/commands/{auto}       + {type: mirror, action: frame} | {type: input, action: tap|swipe|text|key, x, y, x2?, y2?, text?}
projects/{slug}.session.context       {used, window, at}   (built 2026-09-06, with session.pool and session.compacting)
projects/{slug}.session.autopilot     {on, budget, sent, done, nightShift, step?, stepNumber?, waitingUntil?, stoppedFor?, startedAt?}   (built 2026-09-06)
projects/{slug}/commands/{auto}       + {type: autopilot, on, budget?, nightShift?}
projects/{slug}/sessions/{id}         {id, startedAt, endedAt?, firstMessage?, turns, model?, mode?} — the host's list, whole   (built 2026-09-09)
projects/{slug}/commands/{auto}       + {type: start, sessionId?, new?} (a resume from the list, or a new conversation — a running session stops first) | {type: session, action: delete, sessionId}
projects/{slug}~{name}                a worktree's entry: {name: "<Parent> · <name>", parent: <slug>, worktree: {name, branch, path}, dir, machine, manifest, session, …} — no steps, items or counts; its chat, asks, sessions, commands, builds are its own   (built 2026-09-09)
projects/{slug}/commands/{auto}       + {type: host, action: git, op: worktree_add, message: <name>} on a project; op: merge | resolve_merge | worktree_remove (message: force) on a tree
projects/{slug}/runs/{id}/log/{chunk} {from, lines[≤200], at} — the last 10 documents kept (2000 lines), ≤ 1 write/s   (built 2026-09-06)
projects/{slug}/files/{id}            {path, text, lines, truncated}  (text in Storage past 900 KB)
projects/{slug}/builds/{id}           {state, sha, branch, version, size, at, path, progress, error, log, by, name} — the last 3 kept   (built 2026-09-06)
projects/{slug}.session.build         {state, id, progress, version, error, buildOnFlip}
projects/{slug}/commands/{auto}       + {type: build, action: start|delete|switch, buildId?, on?}
projects/{slug}/commands/{auto}       + {type: host|input, action, …}
projects/{slug}/commands/{auto}       + {type: host, action: blocks | step_done, step}   (built 2026-09-10; the result is the CLI's text)
projects/{slug}/commands/{auto}       + {type: brief, text} | {type: host, action: write_file, path, text, base?}   (built 2026-09-10)
projects/{slug}.session               + brief (the user's block), briefFixed (the kit's lines)   (built 2026-09-10)
projects/{slug}/files/{id}            + stamp (the file's mtime, ms) — what a save hands back as `base`
projects/{slug}/inbox/{auto}          + entries {kind: reorder, id, before} | {kind: step_done, id}; the host stamps appliedAt, applied, lines   (built 2026-09-10)
projects/{slug}/chat/{auto}           + sessionId, parent? (the Agent tool_use_id a subagent's row hangs under), doneAt?, toolOutput? (≤ 24 KB), toolOutputCut?, progress? (an Agent row), diff?, turn?, by? (`autopilot` on the loop's /step rows)
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
6. The CLI's transcript file under `~/.claude/projects/<cwd-key>/` for session history: **read** 2026-09-09 on 2.1.261 (below).

### Session history (built 2026-09-09)

The bridge record is a list: `~/.flutter_kit/bridge/<slug>.json` →
`{sessionId, sessions: [{id, startedAt, endedAt?, firstMessage?, turns,
model?, mode?}], …options}` — `sessionId` is the current one, what Resume
resumes; a record from before the list reads as one entry. The host fills
an entry in as the session goes (the first message on the first send, a
turn per `result` with turns, the model from `init`, the end on exit) and
mirrors the list to `projects/{slug}/sessions/{id}`, one document each,
deleted when gone. Both Decks and the Session tab show a **Sessions**
card — the conversation on the Deck, NEW, ALL — and a sheet with every
session newest first, RESUME and a bin on each. Resume from the list and
New stop a running session first, between turns (mid-turn the command is
refused with a line), and stop the autopilot with it. Delete takes a
session off the list only; the current one, stopped, empties the Deck
with it. The rows on the Deck belong to one conversation: a switch to
another session clears them and reads the tail back from the CLI's
file; a resume of the conversation already shown keeps its rows and reads
nothing. The phone hides any mirrored row whose `sessionId` is not the
current session's, so a switch never shows two conversations while the
mirror catches up.

**The file's shape** (`<id>.jsonl`, 2.1.261): one JSON object per line.
`user` lines carry the person's prompt — `message.content` a string, or
`text` blocks; a slash command is kept as
`<command-name>/step</command-name>\n<command-args>…</command-args>` — or
a tool's result (`tool_result` blocks with `tool_use_id`, the content a
string or `text` blocks); `isMeta: true` marks text the CLI injected,
`isSidechain: true` a subagent's thread. `assistant` lines carry one
content block each (`text`, `tool_use`, `thinking`) with `message.model`
and `timestamp`. The rest — `ai-title`, `mode`, `permission-mode`,
`queue-operation`, `last-prompt`, `atis-latch`, `attachment`,
`system/local_command`, `bridge-session`, `file-history-snapshot` — is
bookkeeping. `kit/lib/src/history.dart` reads the last 80 rows back
(`restoreRows`, ids `h…` so they sort before the live `m…` rows) and a
summary (`summarizeTranscript`: first prompt, turns, model, span) for an
entry the record had nothing on. One thing learned on the live run: the
CLI keys its folder by the path it ran in, *resolved* — a project under
`/var/…` is `/private/var/…` to it — so `ClaudeCli.projectStateDir`
takes the resolved path's folder when it exists; before this, a resume
of such a folder found no file, started fresh, and said so only in the
log (`switchTo` now returns that line). Two more from the relaunch: an
entry from before the list knew nothing but its id, so the host now reads
its file once at construction (first prompt, turns, model, the last line
as its end) and writes the record; and `ship.sh` opened the new app while
the old one was still saying goodbye to the relay, so nothing relaunched
— it now waits for the old process to be gone.

### Worktree sessions (built 2026-09-09)

One driver per folder; a worktree is another folder. **NEW TREE** on the
Git card of a project (both devices) takes a name — letters, digits,
dots, dashes, underscores; it is the branch and the folder — and the
host runs `git worktree add ~/.flutter_kit/worktrees/<slug>/<name> -b
<name>` from the project, copies the parent's `.claude/settings.json`,
`settings.local.json` and `commands/` where git did not bring them (the
tree has what git tracks), marks the tree trusted in `~/.claude.json`
when the parent is (`ClaudeCli.trustLike`, a read-modify-write written
as the CLI writes it), and opens the tree as a project of its own:
`HostProject(parent:, worktreeName:)`, slug `<slug>~<name>`, name
`<Parent> · <name>`, its own bridge, chat, asks, sessions, run bay and
commands — listed under its parent with a branch glyph on both devices
(`HostProjects.getWorktree` / `worktreesOf`; the phone groups by
`parent`, `groupProjects`). Trees on disk come up with the parent at
launch (`worktreeNamesOf`). The plan is the main tree's: a worktree's
publisher writes its project document only — no steps, items or counts
— the phone shows the parent's plan for a worktree and sends batches to
the parent's inbox, and the brief (`worktreeBrief`) tells the session
it is on branch `<name>`, to commit there only, and to leave `plan/`
and `kit step/gate/done/item` to the main tree. Both trees run at
once; pushes carry `<Parent> · <name>`.

**MERGE INTO MAIN** on a worktree's card, with its session stopped
(refused otherwise, and while the main session is mid-turn): `git merge
--no-ff --no-edit <name>` in the main folder. A clean merge names its
commit — a git row on the main Deck and a host note for the main
session's next prompt. A conflict leaves main as git left it, lists the
files (`git diff --name-only --diff-filter=U`) and the card offers
SEND — "resolve the merge of `<name>` …" to the main session, resumed
if idle. **REMOVE**: refused while the tree's session runs; `dirty: n
changed` until FORCE; `git worktree remove [--force]`, then the relay
entry and its rows go (`deleteProject`) and the project closes two
seconds after the command's stamp — the phone waits on that very
document for its line, so the entry's rows must not go with it (found
on the live run). The branch stays. Proven 2026-09-09 over the relay on
~/kit-scratch: tree, session on the branch, clean merge, a conflict
sent to the main session and resolved by it in 21 s, a dirty remove
refused then forced.

Looked at on the phone in hand 2026-09-10 (adb-driven from the
session, screenshots read back), the whole walkthrough for this step
and for session history. First finding was the phone itself: it had
been on the 6 September APK since try-it — that step's sharing plugin
(`receive_sharing_intent` 1.9) compiles against API 37 while the app
compiled against Flutter's default 36, the Android build had failed on
every ship since, and `ship.sh` copied the last good APK over without
a word. The app now compiles against 37
(`android.suppressUnsupportedCompileSdk=37` for AGP 9.0's note) and the
script deletes the old outputs before it builds, so a failed build
ships nothing. Then, on the real screens: REMOVE left the phone on the
removed tree's screen, an empty Deck with a NEW TREE button on it —
the Git card now pops its screen once the line says removed, and the
entry leaves the list two seconds later; the tree's bridge record
(`~/.flutter_kit/bridge/<tree-path>.json`) survived the removal and
handed its sessions to the next tree made under the same name — it is
forgotten with the tree (`BridgeSession.forgetRecord`); NEW TREE under
a name whose branch survived a removal failed on git's "already
exists" — the host now checks the existing branch out again and says
so; the tree's title read "SCRATCH · S…" — the fold's title wraps to a
second line. And the context arc carried the last session's reading
onto a NEW one until its first call — a fresh or switched conversation
starts the arc at nothing.

### Rich pushes (built 2026-09-10)

A push should be enough to decide on from the lock screen. Three
things it lacked: a picture of what the turn did, the lines an ask is
about, and a night's sleep.

**A frame in the Done push.** When a turn ends while the run bay has
the app up, the host takes one shot the mirror's way (`Mirror.shot`:
captured and shrunk, nothing published, the live frame untouched),
puts it at Storage `projects/{slug}/shots/{ms}.jpg` (the last five
kept) and the Done notice carries the path as `image` — with the
turn's `sessionId` and `rowId` (the user row whose turn ended). The
phone fetches the frame through the Storage SDK as the signed-in user
(`LocalNotices.fetchShot`; a download URL would have been one more
token to expire) into a temp file and draws a big-picture notification,
the words as its summary; a fetch that fails is the words alone. The
tap opens the Deck on that row (`focusRowId` from the push through
`ProjectScreen.remote` to `DeckView`, landed on once with the same
settle the since-line uses). No run, no picture.

**Words to decide on.** An Edit or Write ask's push carries the diff's
first three changed lines under the summary (`diffPreview`); a plan
push carries the plan's first heading and its step count
(`planOutline`: numbered items, else bullets, else the headings under
the first); a problem push carries the error's first line as it was
(`errorLine`, 480 chars). All in `kit/lib/src/pushes.dart`, pure.

**Quiet hours.** A window per phone, on its `devices/{token}` row —
`quiet: {on, start: "HH:MM", end: "HH:MM", offset}` in the phone's own
clock with its UTC offset in minutes (`QuietWindow`; a window may cross
midnight) — set from the moon on the phone's project list
(`QuietHoursSheet`: a switch, two time pickers, every change written at
once; 23:00–08:00 to begin with). The host's `PushSender` reads the
windows off the rows it already watches: a notice that waits
(`heldInQuiet` — Turn ended, Claude's own line, a problem that is not a
dead session) for a phone inside its window is held under that token
instead of sent; a timer for the earliest window's end sends one
digest per project (`digestNotice` — "While you slept · 3 turns ended
· 1 problem", the last turn's first line under it, on the problems
channel when a problem is among them) and re-arms. The rows changing —
the window moved, switched off, the phone gone — re-arms too, so a
window turned off flushes at once. Asks, steps, builds and a dead
session (`Notice.urgent`, set by `TurnWatch` for a failed session) go
through. The Session tab says which phones keep a window and how many
notices wait for this project.

Proven 2026-09-10 on the phone in hand, driven over adb, against
~/kit-scratch with RUN up on the simulator: the Edit ask's push showed
the two changed lines; the Done push's tap (the notification's own
`SELECT_NOTIFICATION` intent) opened the Deck on the turn's row; a
turn during quiet hours pushed nothing, the window's end moved two
minutes ahead brought "While you slept · Scratch — 1 turn ended" on
the minute; an ask went through the window in 8 s and a killed session
brought "Problem · Scratch" with the exit line in 3 s. The frame came
last: on the first run every Storage write on `flutterappbundle` failed
with `quota-exceeded` on a bucket holding two objects — the card on the
Blaze billing account had been closed, and a suspended account drops the
project to the no-cost limits, where a `firebasestorage.app` bucket
takes no writes at all. With the card replaced the same night, the
mirror's frame command answered "frame 1 · 331×720" and a turn with RUN
up pushed "Done · Scratch" as a big-picture notification carrying the
331×720 shot from `projects/scratch/shots/`. Two things found on the
run: the shot's failure, logged into the bridge, came back as the dead
session's reason ("claude exited with code -9 — shot: …") — the
bridge's last log line is its exit reason, so the shot keeps its own
(`HostProject.shotError`, on the Session tab); and a fresh session kept
the dead one's error line on the relay, because the host omitted the
`error` key when there was none and the merged write kept the old
value — the key is always written now, null when clear.

### Constellation controls (built 2026-09-10)

The constellation shows the plan; now it drives it, with no model in
the loop. A bubble's panel and its sheet carry three controls under the
title. **Start this step** sends `/step <id>` to the session — while none
runs the button reads START THE SESSION and starts one first, and reads
START THIS STEP once the Deck shows it live. **Blocks** is `kit blocks
<id>` run by the host (`{type: host, action: blocks, step}`): the
rendering the CLI prints — dependencies, gates, the human items and whose
move it is — lands under the buttons in mono. **Mark done** is `kit step
done <id>` run by the host (`{type: host, action: step_done, step}`): a
refusal comes back word for word ("b: gates not passed: tests. Record
them with `kit gate`, or --force.") in red; a flip returns "b: done." and
the steps it made ready, the host re-renders the plan markdown and the
board, and the bubble turns done on both devices as the mirror catches
up. The step moves themselves live in `kit/lib/src/steps.dart`
(`stepStart`, `stepDone`, `stepDoneRefusal`, `reorderedSteps`,
`reorderStep`, `planWithMoves`, `hostOnlyBatch`); the CLI's `kit step`
calls the same functions, so a refusal reads the same whichever door it
came through, and `kit step move <id> [--before <id>]` is new.

**Reorder by drag.** A long press lifts a bubble (a haptic tick, an
accent ring under the finger); carried past another bubble — the nearest
within 70 canvas px wears a wide ring — and released, the step goes
*past* it: before it when dragging back, after it when dragging forward.
The drag stays on the device: the draft gains `moves` (`StepPlace(id,
before)`, the last drag of a bubble wins), the constellation and the
sheets draw the plan as the moves would make it (`planWithMoves`, nothing
written; a moved bubble wears a dashed amber ring and RANK n · MOVED),
and the draft bar reads **APPLY** when the draft holds only moves — the
Mac applies those by itself, so nothing goes to Claude. The batch's
entries are `{kind: reorder, id, before}`; `applyInbox` gained that op
and `{kind: step_done, id}` (a refusal is a skipped line carrying the
reason). Ranks move as little as the order allows: the moved step takes
the middle of the gap it lands in, and only when there is no gap do the
steps after it shift up by one until the order is strict again; numbers
never change (`kit status` shows the order, the numbers ride along). The
host notes the moved ranks in the step's history and tells the session
on its next prompt ("From the app: step c moved before b …"). The phone
waits for the batch's `appliedAt` and shows the Mac's lines.

### Brief and rules (built 2026-09-10)

The human's rules evolve where the human is. Two editors, on the Mac's
Session tab and in the Deck's fold of both devices (BRIEF · n LINES,
RULES · CLAUDE.MD pills under the dials).

**Brief.** The standing brief keeps its fixed part — the kit's lines:
driven from a phone, the browser, sign-ins as questions, store actions
asked first — and gains a per-project part the user writes. It lives in
the bridge record (`brief`), rides `--append-system-prompt` as its own
block under the fixed text (`deckBrief(custom:)`, headed "Project brief
— the user's standing rules for this project …", before the worktree
and run-bay lines the host adds), and the session document carries both
parts (`session.brief`, `session.briefFixed`). The editor folds the
fixed text above a plain field; Save is `{type: brief, text}` and the
host's line says when it applies — at the next Start, or, while a
session runs, when its process starts again (Start, Resume, or a Chrome
or effort change): the brief is on the command line, and mode and model
switch in place without one. The Session tab shows the block under the
fixed text.

**Rules.** `CLAUDE.md` and the `qa.note` paragraph of `plan/kit.yaml`
open in a plain editor with the mono face (`rules_editor.dart`; the two
targets in `kit/lib/src/rules.dart`, the note as the path
`plan/kit.yaml:qa.note`). A read carries the file's modification time
as a `stamp` (`FileRead.stamp`; the note carries kit.yaml's). Save is
`{type: host, action: write_file, path, text, base}`: the host
(`RulesWriter`) refuses when the stamp moved — "refused: changed on
disk since you opened it — reload, then save again", which the editor
turns into a Changed-on-the-Mac dialog with KEEP EDITING and RELOAD —
else writes the one file (the note by a YAML patch, the rest of the
manifest untouched) and commits just that file with `git add -- <path>
&& git commit -m … -- <path>`, named "rules: <the first line that is
new>" (`rulesCommitMessage`: a removed line reads "rules: removed: …",
nothing else "rules: <name> edited"). A dirty tree elsewhere is left
alone; without a repository the line reads "saved, not committed". A
project without a CLAUDE.md reads as an empty file and the first save
creates it. The session hears every save as a host note ("CLAUDE.md was
edited from the app and committed as … — read it again") and sees a
`rules` row. Both editors scroll as one and keep Save as the bottom bar,
so the largest text sizes stack rather than overflow.

Proven 2026-09-10 on the phone in hand once the user unlocked it —
the Turkish rule typed into the fold's BRIEF editor and saved, Start,
"hi" → "Merhaba! Nasıl yardımcı olabilirim?"; RULES · CLAUDE.MD reading
the file over the relay, a line appended and saved as "[main 0273011]
rules: - From the phone." with that one file in the commit; a line
appended on the Mac behind the open editor → Save refused with the
dialog, RELOAD showing the Mac's line; the qa note target — and, before
that, on the Mac's own window, driven from the session with real mouse
events while the phone was locked behind its fingerprint:
"Always answer in Turkish." saved from the Deck's BRIEF pill ("Saved.
It applies at the next Start."), the record on disk holding it, Start,
"hi" → "Merhaba! Ben buradayım…"; the Session tab showing the block
under the fixed text; a line appended to the scratch CLAUDE.md and
saved → "saved and committed — [main d86b532] rules: - Answer in one
line." with `git log -1 --stat` naming that one file; the file changed
on the Mac behind the open editor → Save refused with the Changed-on-
the-Mac dialog, RELOAD showing the Mac's line; the qa note target
reading the manifest's field. The phone's road — `{type: brief}` and
`write_file` over the relay — was sent by hand to the live host: the
stale save came back refused in 80 ms and the brief cleared with "applies
when the session starts again". Three things found: a save of a file whose
last line had no newline left the file without one (a trailing newline
is added now); the Save bar as the Scaffold's bottom bar sat behind the
phone's keyboard, since a bottom bar does not rise with it — the bar is
the last child of the body now, so it rides above the keyboard; and a
mouse tap that lands while a list is still settling from a wheel scroll
stops the scroll instead of pressing — a fact about driving the Mac, not
the app.

### Codex engine (built 2026-09-10)

The host has a second engine. Nothing on the phone or in the relay knew
which engine runs; now the **ENGINE** notch — `claude` · `codex`, the
first dial in the Deck's fold on both devices and a segmented control on
the Session tab — names it per project, switched while no session runs. A
session belongs to the engine that made it: `sessions/{id}` carries
`engine`, and Resume from the list moves the notch to match.

**What was proven first (spikes, 2026-09-10, Codex 0.153.4 inside the
ChatGPT app, a Pro login — the plan read `plus` on 2026-09-06):**

| # | question | answer |
|---|---|---|
| 1 | Does a question reach the client? | **Yes**, with `--enable default_mode_request_user_input`. "Ask me tea or coffee with request_user_input" arrived as the server request `item/tool/requestUserInput` `{questions: [{id: drink, header, question, isOther: true, isSecret: false, options: [{label, description}]}], isBlocking: false}`; the result `{answers: {drink: {answers: ["Coffee"]}}}` continued the turn — *"You chose coffee."* The thread's status read `active · waitingOnUserInput` meanwhile. The warning `Under-development features enabled` comes with every thread. |
| 2 | Does a permission reach the client, and does a denial hold? | **Yes**, under `approvalPolicy: untrusted` (not `on-request`, which runs `touch /tmp/x` inside the workspace-write sandbox without asking). `touch /tmp/kit-codex-1` arrived as `item/commandExecution/requestApproval` with `command` (`/bin/zsh -lc '…'`), `commandActions[0].command` (the plain words), `proposedExecpolicyAmendment: ["touch", "/tmp/kit-codex-1"]` and `availableDecisions`. `{decision: decline}` → the item completed `declined`, no file, *"the command was rejected"*. `{decision: {acceptWithExecpolicyAmendment: {execpolicy_amendment: […]}}}` → the file, and Codex wrote `prefix_rule(pattern=["touch", "/tmp/kit-codex-1"], decision="allow")` to `~/.codex/rules/default.rules` — Codex's **Always**. |
| 3 | Where does plan mode live? | **On `turn/start`**, as `collaborationMode: {mode: plan, settings: {model}}` — not in the 0.153.4 schema (the features list says `collaboration_modes` graduated), but the server takes it: `thread/settings/updated` echoed `collaborationMode.mode: plan` with the server's own plan-mode developer instructions, the plan streamed as 53 `item/plan/delta`s into a `plan` item, and README.md did not change. `thread/resume` of that thread plus *"Implement the plan."* in default mode produced a `fileChange` item `{changes: [{path, kind: {type: update}, diff}]}` and the line landed. |
| 4 | Does the ChatGPT app's browser come up under a host-spawned app-server? | **No.** The `chrome` and `browser` plugins' MCP servers (`cua_repl`, `node_repl`) start and report `ready`, but `cua.getBrowser({url})` answers *"No browser is available"* — the browser is the ChatGPT app's own, alive only while the app runs the thread. The Drive Chrome pill reads **BROWSER · NOT ON CODEX**; nothing else depends on it. |

| decision | answer | why |
|---|---|---|
| One runner, two engines | `BridgeSession` stays the runner — the record, the sessions list, the queue, the host notes, the asks, the options, the brief, the Always rules, the relay — and calls an `Engine` (`app/lib/src/host/engine.dart`) for what goes down the pipe and what comes back: `ClaudeEngine` wraps the pure functions of `kit/lib/src/bridge.dart`; `CodexEngine` (`codex_engine.dart`) wraps `CodexTranslator` (`kit/lib/src/codex.dart`, pure Dart, every shape captured). Autopilot, night shift, instruments, crew chips, review, run bay, mirror, builds, attachments, interrupt, the queue: unchanged above the interface — they read the transcript. | The step asked for `ClaudeSession`/`CodexSession`; a strategy inside one runner shares more and changes less. |
| The MODE notch on Codex | default → `approvalPolicy: untrusted` + `sandbox: workspace-write` (a `touch` asks, as on Claude); accept edits → `on-request` + `workspace-write` (Codex's own Auto: edits and sandboxed commands run, an escape asks); bypass → `never` + `danger-full-access`; plan → `collaborationMode: plan` over a read-only sandbox. All four ride on every `turn/start`, with `model` and `effort` — nothing restarts, no control request; the dial moves at once and the facts line says so. `thread/settings/updated` reads the notch back. | Spike 2: `on-request` would have run the marker file without a card. |
| Always | The ask's `suggestions` carry `{type: execpolicy, pattern}`; Always answers `acceptWithExecpolicyAmendment` and the record keeps an `AppliedRule(destination: execpolicy, tool: prefix_rule)`; the Session tab lists it as `prefix_rule(touch /tmp/kit-codex-1) · allow, execpolicy` and Remove rewrites `~/.codex/rules/default.rules` without that line (`ExecPolicyRules`, `codex_cli.dart`). **This session** stays host-side memory, as today. A patch has no Always. | Codex's rule file is the settings file's counterpart; the phone should see and undo what it granted. |
| The plan card | Codex has no `ExitPlanMode`: the plan is the turn's `plan` item. At `turn/completed` in plan mode the translator raises an `ExitPlanMode` ask of its own (`requestId: plan-<turn>`, `input.plan` = the plan text, `engine: codex`) — the same card, the same push *Plan ready*. Approve writes nothing to the server: the runner moves the dial to default (`setMode`, as on Claude) and sends *Implement the plan.* as the next turn; Revise sends the words back as a plan-mode turn. | One card on the phone, whatever the engine. |
| `/clear`, `/compact`, `--resume`, interrupt | `/clear` is a fresh `thread/start` with `sessionStartSource: clear`; its response reads as a reset, a new init (the new thread id — a new entry in the list; the old one ends) and a result of no turns, so the loop's clean context per step holds by construction. `/compact` is `thread/compact/start`; `thread/compacted` is the compaction note. Resume is `thread/resume {threadId}` and the thread's turns come back as rows (`itemsView: full`). Interrupt is `turn/interrupt {threadId, turnId}`; the turn completes `interrupted`. | The step's map, proven. |
| Tokens and the pool | `thread/tokenUsage/updated.last` is what the model read on its last call (`inputTokens` cached included, `cacheWriteInputTokens`) against `modelContextWindow` (258,400 for gpt-6-astra) — a `UsageEvent` the transcript folds in. `account/rateLimits/updated` names windows by length: 300 minutes is the five-hour arc, 10,080 the weekly; the Pro account reported only a weekly `primary` (`usedPercent: 9`), so the five-hour arc may be empty on Codex and the countdown reads the window there is. A `usageLimitExceeded` / `rateLimitExceeded` error, or `rateLimitReachedType`, is the pool refusing — night shift waits on the last `resetsAt`. | Two engines are two pools; the arcs show the running engine's own. |
| The sandbox and the kit | A workspace-write turn also names `writableRoots`: the Flutter SDK's `bin/cache` (its `dart` wrapper stamps the engine version on every run — inside the sandbox that write is refused and `kit` dies before it starts, found on the first autopilot run 2026-09-10), the tools' folders under the home (`~/.pub-cache`, `~/.dart-tool` — Dart's telemetry config was the next refusal — `~/.dart`, `~/.flutter`), and the plugin's own `kit/` under Codex's plugin cache (its compiled binary). An ask's `requestId` is `cx-<thread>-<salt>-<n>`: the server counts requests from 0 in every process and a resumed thread keeps its id, so a stale answer from the last process must not land on a new ask. The host finds the SDK through `dart` on the shell PATH once; the plugin root from where `skills/list` put the kit skills. | The kit must run where Codex runs it, without a card for every `kit next`. |
| Questions in Codex's name | `Ask.engine` (`claude` default) rides the relay; the card reads **CODEX ASKS**, the push *Codex asks · project*, `kit notify` pushes *Codex · project*. The Android channel stays *Claude needs you* — a channel is a device setting, renaming it would orphan the user's choice. | The phone says who is asking. |
| The brief on Codex | `developerInstructions` on `thread/start`: the same standing rules in Codex's words (`codexBrief` — `request_user_input` for questions and sign-ins, "questions never as plain text", the plan as the plan item, the browser as the app's own when it is there). The user's block and the worktree and run-bay lines follow as on Claude. | A Codex session that asks in text is a question the phone never sees. |
| The plugin's second home | `.codex-plugin/plugin.json` beside `.claude-plugin/plugin.json`; `.agents/plugins/marketplace.json` makes the checkout a local marketplace (`codex plugin marketplace add <checkout>` · `codex plugin add flutter-kit@flutter-app-bundle` — done on this Mac 2026-09-10; Codex copies the plugin to `~/.codex/plugins/cache/flutter-app-bundle/flutter-kit/2.0.0`, refreshed on a version bump, the same symlink trick as Claude's cache). The 19 commands are generated skills `skills/kit-<name>/SKILL.md` (`tool/codex/generate.py`) — `$kit-step`, `$kit-next`… — with a preamble that names the plugin root (Codex substitutes nothing in a skill; `${CLAUDE_PLUGIN_ROOT}` is for hooks only) and `$ARGUMENTS` as the words after the mention; the `kit-` prefix keeps Claude Code, which reads `skills/` too, from seeing a skill and a command under one name. The 9 agents are profiles `assets/agents/<name>.toml` that `$kit-codex-setup` (`tool/codex/setup.sh`) copies into a project's `.codex/agents/`, with `project_doc_fallback_filenames = ["CLAUDE.md"]` in its `.codex/config.toml`. `hooks/hooks.json` as is, its `Write\|Edit` matcher widened to `apply_patch` and `analyze-queue.sh` reading the paths out of a patch; Codex ignores the `Notification` entry and runs the rest once trusted (`/hooks` in its TUI — the item). On the host, `/step x` becomes a `skill` input item (`{type: skill, name, path}` with the name as `skills/list` lists it — a plugin's skills come namespaced, `flutter-kit:kit-step` on 0.153.4 — and the text *Use the $kit-step skill with: x*) when the list has it; autopilot stops with a line when it does not. Two things the install showed: Codex lists all 39 skills of the plugin (the 19 Dart/Flutter ones too), and it migrates a few of `commands/` into `migrated-command-skills/` under the cache copy's `.codex-plugin/` on its own (four of the 19 on 0.153.4) — the generated `kit-*` skills are the ones to use. | Codex reads `skills/` and `hooks/`, not `commands/` or `agents/`. |

The map, as built — every line of it captured in `kit/test/codex_test.dart`:

```
host → server   initialize {clientInfo, capabilities: {experimentalApi}} · initialized · model/list · skills/list {cwds}
                thread/start {cwd, approvalPolicy, sandbox, model?, developerInstructions, sessionStartSource?: clear}
                thread/resume {threadId, …}  ·  account/rateLimits/read
                turn/start {threadId, input: [{type: skill, name, path}?, {type: localImage, path}*, {type: text, text}], approvalPolicy, sandboxPolicy, collaborationMode, model?, effort?}
                turn/interrupt {threadId, turnId}  ·  thread/compact/start {threadId}
                ← answers: {decision: accept | decline | {acceptWithExecpolicyAmendment}} · {answers: {<question id>: {answers: [text]}}} · {permissions, scope: turn}
server → host   thread/started · turn/started · item/started · item/completed (userMessage, agentMessage {phase}, plan, commandExecution {command, commandActions, status, aggregatedOutput, exitCode}, fileChange {changes: [{path, kind, diff}]}, mcpToolCall {server, tool, arguments, result}, webSearch, collabAgentToolCall, subAgentActivity, contextCompaction, reasoning…)
                item/agentMessage/delta · item/plan/delta · item/commandExecution/outputDelta
                item/commandExecution/requestApproval · item/fileChange/requestApproval · item/tool/requestUserInput · item/permissions/requestApproval   (requests, answered by id)
                turn/completed {turn: {status: completed | interrupted | failed, error, durationMs}} · thread/tokenUsage/updated · account/rateLimits/updated · thread/settings/updated · thread/compacted · mcpServer/startupStatus/updated · error {willRetry, error: {message, codexErrorInfo}} · warning
```

Relay additions: `session.engine` (`claude` | `codex`), `session.provenOn`,
`session.models` (what the running engine listed, for the dial),
`sessions/{id}.engine`, `asks/{id}.engine`, and `options` carries
`engine` (refused while a session runs). The facts line reads
`codex 0.153.4`; a version other than the proven one says so.

**QA (2026-09-10, on the Mac window and over the relay — the phone was off USB, so the phone's screens are the widget tests at phone width):** `{type: options, engine: codex}` moved the notch and the facts line read `codex 0.153.4`; Start over the relay brought the thread up (`model/list` filled the MODEL dial with six GPTs, the weekly pool read 9 %); *"What model are you?"* → *"I'm Codex, based on GPT-6."* with `21.1K CTX · 15 OUT` on the row. `touch /tmp/kit-codex-qa` raised the amber card (`AUTHORIZATION REQUESTED · BASH` with ALLOW · THIS SESSION · ALWAYS · DENY); Deny over the relay held — the row read *declined — the user did not allow it* in red and no file appeared; sent again, Always (by REST — the Firebase MCP refuses a nested-array body) created the file, Codex wrote the `prefix_rule` to `~/.codex/rules/default.rules`, the Session tab listed `prefix_rule(touch /tmp/kit-codex-qa .) · allow, execpolicy`, and its Remove took the line out of the file. The tea-or-coffee question came as **CODEX ASKS · DRINK** with the two options and the own-words field; *Coffee* over the relay → *"You chose coffee."* MODE → plan, *"plan a one-line change to README.md"* → the plan streamed as the reply and the **PLAN READY** card followed with APPROVE · APPROVE · AUTO EDITS · REVISE; Approve moved the dial to default and sent *Implement the plan.*, whose `apply_patch` raised an `AUTHORIZATION REQUESTED · APPLY_PATCH` card showing Codex's own diff (`+Planned from the phone (QA).`) with no ALWAYS; Allow landed the line, and the `git diff` that followed was allowed for this session. Autopilot, budget 2, under accept edits: the first run stalled on an ask — the Flutter SDK's `dart` could not stamp its engine version inside the sandbox — and the second on Dart's telemetry file, both fixed by naming the roots on the turn; the third ran `/step dance` (the kit-step skill through `$flutter-kit:kit-step`, `kit` running inside the sandbox, dance flipped done with its gate) then `/clear` (a new thread, *Context cleared.*) and `/step spin` (gate passed, done refused by its open item, as it should be), and stopped *budget reached*. ENGINE → Claude → Start → the same question answered *claude-fable-5-1* on `claude 2.1.265`; the Claude suites (`KIT_LIVE` off) pass unchanged. Three things fixed along the way: the assistant rows said CLAUDE on Codex (`_Row.engine`); the facts line kept the other engine's version across a switch (`cliVersion` is always written); an ask's id repeated across processes (the salt). The browser plugin's *"No browser is available"* under a host-spawned app-server is the one thing on the map that did not come up; the pill says so.

Later the same day, with the phone on USB, the same walk on the phone in hand (driven over adb; the user's hooks trusted by then): the ENGINE dial dragged to CODEX sent the command and the fold re-read itself (BROWSER · NOT ON CODEX, the Claude version gone from the facts); START brought a thread up; the model answered on a row labelled CODEX; the NOW strip moved on the hooks (*You: …*, *Finished a turn*, then the `apply_patch` PostToolUse) — the first proof that the trusted spool fills under Codex; Deny held on the card, Always wrote the rule; CODEX ASKS took *Coffee* from the option list; MODE dragged to PLAN, the plan card's APPROVE sent the implement turn, its APPLY_PATCH card with the diff was allowed and the line landed; Stop, ENGINE back to CLAUDE, START, and Claude Fable answered on a CLAUDE row. Three more fixes from it: the NOW strip said *Claude finished a turn* whichever engine ran (now *Finished a turn*); rows of the last Claude conversation took the new notch's label while the Deck was idle (`DeckView.rowEngine` — the engine of the session the rows belong to); and the foreground push bar for an ask outlived the ask by a minute, sitting over the composer (it clears on the withdraw push now). A phone call arrived mid-test and the walk paused for it; nothing on the session minded.

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
