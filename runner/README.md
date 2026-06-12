# runner/ — autobuild

Headless, unattended driver that marches the bundle through `PROJECT_PLAN.md`
using the Claude Agent SDK: implement → test → verify on iOS + Android
simulators (demo flavor, fakes) → commit → push, one step at a time.

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
