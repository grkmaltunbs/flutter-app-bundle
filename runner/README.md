# runner/ — autobuild

> **⚠️ PARKED — not wired up in the plugin build.**
>
> This runner predates the conversion to the `flutter-kit` plugin. It invokes
> the `/step` slash command via `setting_sources=["project"]`
> (`autobuild.py:289`), which loaded `.claude/commands/step.md` from the target
> project. `/step` now ships in the plugin, so that lookup finds nothing and the
> runner cannot drive a build as written.
>
> Reworking it means teaching the SDK call to load the plugin, and finding a
> home for the virtualenv that survives plugin updates (`runner/.venv` inside
> `~/.claude/plugins/` gets wiped). The code is kept here for reference until
> then. Everything below describes the pre-plugin behaviour.

Headless, unattended driver that marches the bundle through `PROJECT_PLAN.md`
using the Claude Agent SDK: implement → test → verify on the iOS simulator
(dev flavor, local Firebase emulators) → commit → push, one step at a time.

Use a venv — bare `pip`/`python3` fails with `externally-managed-environment`
on Homebrew Python:

```bash
python3 -m venv runner/.venv
runner/.venv/bin/pip install -r runner/requirements.txt
runner/.venv/bin/python runner/autobuild.py --dry-run        # smoke-test first
caffeinate -i runner/.venv/bin/python runner/autobuild.py    # touch .autobuild-stop to halt
```

Full setup, configuration, and the safety model are in
[`docs/autobuild.md`](../docs/autobuild.md).
