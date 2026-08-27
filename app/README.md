# flutter-kit app

The phase-2 shell. One Flutter codebase, two roles:

- **Host** (macOS today; Windows/Linux are the same code path) — opens a
  project folder that has `plan/`, mirrors it to the relay, applies what the
  phone sends, watches Claude Code's hooks, and starts `claude
  remote-control` in the folder on the user's own login.
- **Remote** (Android first) — reads the mirror, shows the same two screens
  as the board (Steps as bubbles, Your work as sittings), keeps ticks and
  notes on the device until **Send to Claude**, and opens the Remote Control
  session in the Claude app for every command.

The relay is the Firebase project `flutterappbundle` (Firestore in
europe-west3, Email/Password auth, one user, owner-only rules in
`firestore.rules`). Nothing here touches a consumer app's Firebase project.

## Run

```
cd app
flutter run -d macos                      # the host
flutter build apk --release               # the phone: build/app/outputs/flutter-apk/app-release.apk
```

Sign in with the relay user on both. On the Mac: **Open folder** → pick a
project with `plan/kit.yaml`. The Session tab starts Remote Control; the
Claude app on the phone then lists the environment on its own.

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
  host/                claude_cli (binary, trust, bridge pointer) · remote_control (the process) ·
                       hook_watcher (the spool) · host_project (all of it for one folder)
  screens/             sign in · home · project (Steps · Your work · Session) · step detail · item card
```

`flutter_kit` (`../kit`) is a path dependency: model, graph, layout, inbox
and the hook spool are the same code the CLI runs.

## Firestore shape

```
projects/{slug}                 name, dir, machine, manifest, counts, session{state,sessionUrl,environmentUrl}, now{summary,needsYou,at}
projects/{slug}/steps/{id}      Step.toMap()
projects/{slug}/items/{id}      Item.toMap()
projects/{slug}/inbox/{auto}    {sentAt, entries, from}; the host stamps appliedAt + applied
projects/{slug}/events/{auto}   milestones from hooks (prompts, turn ends, notifications)
```

The phone rebuilds a `Plan` from the documents and runs the same `Graph`,
so a bubble is the same colour on both screens and no derived state is
stored anywhere.
