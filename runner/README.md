# runner/ — autobuild

Headless, unattended driver that marches the bundle through `PROJECT_PLAN.md`
using the Claude Agent SDK: implement → test → verify on iOS + Android
simulators (demo flavor, fakes) → commit → push, one step at a time.

```bash
pip install -r runner/requirements.txt
caffeinate -i python3 runner/autobuild.py      # touch .autobuild-stop to halt
```

Full setup, configuration, and the safety model are in
[`docs/autobuild.md`](../docs/autobuild.md).
