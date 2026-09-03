# K.A.T.Y.A — the kit app

**K.A.T.Y.A** (Kodu Anlayan Tecrübeli Yapay Akıl). One Flutter codebase,
two roles. The skin is **Instrument** by night and **Daylight** by day
(`lib/src/theme.dart`); Rajdhani, IBM Plex Sans and JetBrains Mono are
bundled in `fonts/` (OFL). What moves: the session glyph (idle breath,
working radar arc, live pulse, asking double-knock), the thinking dots,
the "now" sweep, the ready step's halo, and the energy waves circling
the session's step in the constellation (dim idle, cyan working, green
done, amber asking) — nothing else.

The two roles:

- **Host** (macOS today; Windows/Linux are the same code path) — opens a
  project folder that has `plan/`, mirrors it to the relay, applies what the
  phone sends, watches Claude Code's hooks, and starts `claude
  remote-control` in the folder on the user's own login.
- **Remote** (Android first) — reads the mirror, shows the **Deck** (the
  conversation with the session: send, attach a screenshot or any file,
  watch it stream, answer what Claude asks, Start / Stop / Resume — all as
  commands the host runs) and the same
  two screens as the board (Steps as bubbles, Your work as sittings), and
  keeps ticks and notes on the device until **Send to Claude**. The Claude
  app is no longer needed for a command; it stays the way in for the full
  terminal (plan mode, `/compact`) until `handover` ships.

Two session options live per project, under Start on both Decks and on
the Mac's Session tab, fixed while a session runs: **Skip permissions**
(`--permission-mode bypassPermissions` — no Allow / Deny cards, every
command runs; Claude's questions still reach the phone) and **Drive
Chrome** (`--chrome` — the session works in the Mac's own signed-in
browser through the Claude in Chrome extension; the pill shows whether
the browser answered). They sit in `~/.flutter_kit/bridge/<project>.json`
beside the session to resume. Every session the app starts is also told,
through `--append-system-prompt`, that it is driven from a phone, what the
browser is, that a sign-in is asked for as a question (you sign in on the
Mac over remote desktop and answer *Signed in — continue*), and that store
actions that cannot be undone are asked about first. The Session tab shows
the text.

The relay is the Firebase project `flutterappbundle` (Firestore in
europe-west3, Email/Password auth, one user, owner-only rules in
`firestore.rules`). Nothing here touches a consumer app's Firebase project.

## Ship a change to the devices

```
bash app/tool/ship.sh          # Mac + Android
bash app/tool/ship.sh mac      # ~/Applications/kit_app.app, relaunched if it was running
bash app/tool/ship.sh android  # ~/Desktop/kit_app.apk, installed over USB when a phone is plugged in
```

Run it after any change under `app/`. The plugin half of the bundle needs
no shipping — Nahmatik's installed plugin is a symlink to this checkout.

## Run

```
cd app
flutter run -d macos                      # the host
flutter build apk --release               # the phone: build/app/outputs/flutter-apk/app-release.apk
```

Sign in with the relay user on both. On the Mac: **Open folder** → pick a
project with `plan/kit.yaml`. The Session tab starts Remote Control; the
Claude app on the phone then lists the environment on its own.

## macOS signing (once per Mac)

Firebase Auth keeps its session in the data-protection keychain, and an
unsandboxed app may only touch that with a `keychain-access-groups`
entitlement — which needs a real signing team. The Xcode project therefore
signs with `DEVELOPMENT_TEAM = 8J4ASHVDQ5` ("Apple Development"), and the
entitlements carry the group. Without it every sign-in fails with *"An error
occurred when accessing the keychain"* (seen 2026-08-28).

`flutter build macos` cannot create the provisioning profile itself. On a
Mac that has never built this app, run once:

```
cd app/macos
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  -derivedDataPath ../build/macos build
```

That registers the Mac in the developer account and caches a "Mac Team
Provisioning Profile"; `flutter run -d macos` works from then on.

## What the host needs from a project

- `plan/` — from `kit import` or `kit init`.
- Workspace trust — Remote Control refuses a folder until `claude` has been
  run there once and the trust dialog accepted (the host tells you).
- Hooks — `kit hook` on `SessionStart`, `UserPromptSubmit`, `PostToolUse`,
  `Stop`, `SubagentStop`, `Notification`, `SessionEnd`. The plugin's
  `hooks/hooks.json` carries them; a project that wires the kit through
  `tool/kit.sh` adds `bash "$CLAUDE_PROJECT_DIR"/tool/kit.sh hook` to
  `.claude/settings.json` instead. Without them the session still works;
  the "now" line just stays empty.

## Layout

```
lib/src/
  plan_source.dart     PlanSource: LocalPlanSource (plan/ on disk, watched) · RemotePlanSource (Firestore)
  relay.dart           Firestore paths, RelayPublisher (host → mirror), InboxListener (host), InboxSender (phone)
  draft.dart           ticks/answers/notes on the device until Send
  attachments.dart     PendingAttachment (a picked file), what may ride inline · attachment_picker (file_selector, or a
                       drop on the Mac window; images shrunk to the API's 1568-px edge) · host/attachment_store
                       (~/.flutter_kit/attachments/)
  host/                claude_cli (binary, trust, bridge pointer) · remote_control (the Claude app's way in) ·
                       bridge_session (this app's way in: `claude -p` over stdio — see ../kit/lib/src/bridge.dart;
                       remembers "this session", records "always") · permission_rules (the settings files the CLI's
                       suggestions name) · hook_watcher (the spool) · host_project (all of it for one folder)
  screens/             sign in · home · project (Deck · Steps · Your work · Session) · deck (transcript, composer) ·
                       ask_card (Allow · This session · Always · Deny, or a question's options — both devices) ·
                       remote_asks (the phone's pending ask, answered as a command) · step detail · item card
```

`flutter_kit` (`../kit`) is a path dependency: model, graph, layout, inbox
and the hook spool are the same code the CLI runs.

## Session options

The Deck header carries what the next Start runs with, on both devices:
two pills, **PERMISSIONS · ASK/SKIP** and **CHROME · OFF/ON**, and two
dials, **MODEL** (default · haiku · sonnet · opus · fable, the CLI's
aliases) and **EFFORT** (default · low · medium · high · xhigh · max).
A dial moves freely and reports once when the finger lifts; `default`
leaves the choice to the CLI. All four are kept in the bridge record
under `~/.flutter_kit/bridge/`. They work while a session runs too: the
flags belong to the process, not the conversation, so the host stops
the process and starts it again on the same session with `--resume` and
the new flags — at once between turns, or when the running turn ends so
nothing in flight is cut (the header says "Applies when this turn
ends"). The facts line under the title shows the model the session
actually got.

Everything under the title — Start/Stop, the pills, the dials — folds
behind a chevron so the transcript gets the screen: open while idle,
folded while a session runs, with a compact Stop kept on the title row;
a tap on the chevron or the title overrides until the session state
changes again.

The conversation is one selection: drag on the Mac, long-press on the
phone, copy — across your bubbles, Claude's replies and tool rows.

## Notifications

The host pushes to the phone itself, over FCM HTTP v1 — no Cloud
Functions. It needs a service-account key for `flutterappbundle` at
`~/.flutter_kit/flutterappbundle-service-account.json` (Firebase console
→ Project settings → Service accounts → Generate new private key; the
file is gitignored under any name with `service-account` in it). Without
the key the Session tab's Checks line says so and nothing else changes.

The phone asks for notification permission at sign-in (the bell in the
app bar shows the state and asks again on a tap) and writes its token
under `devices/`. **PUSH · TEST** on the Deck header, either device,
sends one to every registered phone and toasts what came of it. The
host sends when a session raises an ask — Allow,
a question, a sign-in — or hits a problem: the process died, or a turn
ended in an error — and when a turn ends well, so a task sent from the
phone reports back while the phone is in a pocket. Three Android
channels, **Claude needs you**, **Problems** and **Turn ended**, so any
one can be silenced on its own. A tap opens the project; while the app
is open a bar with OPEN shows instead (none for a turn that ended — the
reply is on the screen), since Android shows no tray notification for a
foreground app. The session is told all this in its brief, because the
CLI's own PushNotification tool has no route from a bridge session: it
only knows Anthropic's Remote Control pairing with the Claude app.

A session can push a line of its own: `kit notify "Build uploaded"` in
the project folder writes one `Notify` event to the hook spool, and the
host sends it as "Claude · project" on the Turn ended channel. The brief
tells every session the command exists and when to use it — when you
asked to be told at a point, not at every step.

`dart run tool/push_probe.dart [fcm-token]` (from `app/`) proves the key
mints a token and FCM answers; without a token it sends to a probe token
and FCM's 400 about that token is the proof.

## Firestore shape

```
projects/{slug}                 name, dir, machine, manifest, counts, session{state,sessionUrl,environmentUrl}, now{summary,needsYou,at}
projects/{slug}/steps/{id}      Step.toMap()
projects/{slug}/items/{id}      Item.toMap()
projects/{slug}/inbox/{auto}    {sentAt, entries, from}; the host stamps appliedAt + applied
projects/{slug}/asks/{requestId} an Ask; the host stamps answeredAt, answer, by — 'Withdrawn' when the process ended with it open
projects/{slug}/events/{auto}   milestones from hooks (prompts, turn ends, notifications)
projects/{slug}/threads/{about}          `item:<id>` or `step:<id>` — {about, count, last, updated}
projects/{slug}/threads/{about}/messages the scoped rows, append-only; they outlive sessions and the chat window
projects/{slug}/uploads/{id}             a file on its way from the phone {name, mime, size, parts, complete}; parts/{n} hold 600 KB
                                         of base64 each; the host saves it under ~/.flutter_kit/attachments/ and deletes the upload
devices/{fcmToken}                       a phone that takes pushes {platform, name, uid, registeredAt, seenAt}; the host drops one FCM no longer knows
```

The phone rebuilds a `Plan` from the documents and runs the same `Graph`,
so a bubble is the same colour on both screens and no derived state is
stored anywhere.
