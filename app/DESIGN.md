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
| Permissions and questions | Every `control_request` becomes `projects/{slug}/asks/{id}` in the relay; the phone shows it as an **authorization card** (and, in the background, a notification with Allow / Deny actions); the answer goes back as `control_response`. **Allow for this session** is remembered by the host for identical requests; **Always** applies the CLI's `permission_suggestions` to the project's `.claude/settings.json` and lists it on the Session screen. | Claude asks; you answer from the lock screen. Nothing runs that you did not see. |
| The Claude app stays available | **Hand over** stops the bridge and starts `remote-control --session-id` on the same transcript; **Take back** does the reverse. One driver per project at a time — the host refuses a second. | Plan mode, `/compact`, the full TUI remain one tap away, on the same conversation. |
| Asking about one item | A message carries `about: {item: id}` or `{step: id}`. The host prefixes the prompt with `kit show <id>` and a standing instruction: answer for a phone screen; if the item should change, change it with `kit` or by editing its YAML and say what changed. The plan watcher mirrors the edit; the card shows the thread and an **UPDATED** strip. Threads persist under `projects/{slug}/threads/{about}`. | Appearance is derived from data; Claude changes the data. No second state. |
| Notifications | FCM HTTP v1 **from the host**, with a service-account key on the Mac (already gitignored). Milestones (needs you, turn ended, step flipped) and asks. Android notification actions answer an ask without opening the app. | No Cloud Functions, no Blaze, no server. iOS needs an APNs key — a human item. |
| Attaching a file | The paperclip on the composer, both devices; on the Mac, a drop on the Deck too. The phone puts the bytes up in 600 KB base64 parts under `uploads/`; the host reassembles, saves under `~/.flutter_kit/attachments/`, sends images inline and every file by path, and deletes the upload. Images are shrunk on the device to the 1568-px edge the API scales to. | No Storage bucket (Blaze), no second transport. Firestore's free tier carries a screenshot in a second, and nothing stays in it. |
| Skipping permissions | A per-project option, kept in the bridge record and flipped from either device while no session runs: Start adds `--permission-mode bypassPermissions`. Questions still arrive — an `AskUserQuestion` under bypass came over stdio and its answer was read back (2026-09-03, 2.1.258). | It is `--dangerously-skip-permissions` by another name, so it is a switch the user throws, never a default; and the phone still gets the questions, which is the half of the ask model that matters when nothing else is asked. |
| The browser | A second option: Start adds `--chrome`. Headless, the session's `init` listed `claude-in-chrome: connected` and the browser tools (navigate, find, form_input, get_page_text, computer, file_upload) on 2026-09-03; the pill shows that status while running. App Store Connect, Play Console, RevenueCat are the Mac's own logged-in Chrome tabs, driven from the phone; each browser action asks unless permissions are skipped. | The extension is on the Mac already; no Playwright profile to sign in, no second browser. |
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
| `assistant` | final content: text → the message; `tool_use` → a compact tool row |
| `user` (tool_result) | closes the tool row with its result summary |
| `control_request` / `can_use_tool` | writes `asks/{request_id}`; `AskUserQuestion` renders as a question card, anything else as an authorization card; waits for the answer |
| `result` | closes the turn; `chat` gets the summary; `session.state = idle` |
| `rate_limit_event` | shows the pool and its reset time on the Session screen |

A `control_request` is answered by whichever surface answers first — the
Mac window, the phone card, or a notification action — and the others
collapse. The host answers on its own only for a request identical to one
the user allowed "for this session".

## Firestore shape (additions to phase 2)

```
projects/{slug}.session               {mode: bridge|remote|idle, sessionId, model, startedAt, pool{resetsAt}, skipPermissions, chrome, chromeStatus?}
projects/{slug}/chat/{auto}           {role: user|assistant|tool, text, about?, tool?, status?, at}
projects/{slug}/asks/{requestId}      {kind: permission|question, tool, input, suggestions, description, at, answer?, answeredAt?, by?}
projects/{slug}/threads/{about}/messages/{auto}   the per-item / per-step conversation
projects/{slug}/commands/{auto}       phone → host: {type: start|stop|send|options|handover|answer, payload, uploads?, at, doneAt?}
projects/{slug}/uploads/{id}          a file on its way from the phone: {name, mime, size, parts, complete, from, sentAt}
projects/{slug}/uploads/{id}/parts/{n}  base64, 600 KB of the file each; the host deletes the upload once saved
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
| 6 | `notifications` | An ask arrives as a notification with actions while the app is closed; Allow from the lock screen runs the command | a service-account key on the Mac |
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
