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
  host/                claude_cli (binary, trust, bridge pointer) · remote_control (the Claude app's way in) ·
                       bridge_session (this app's way in: `claude -p` over stdio — see ../kit/lib/src/bridge.dart) ·
                       hook_watcher (the spool) · host_project (all of it for one folder)
  screens/             sign in · home · project (Deck · Steps · Your work · Session) · deck (transcript, ask card,
                       composer) · step detail · item card
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
