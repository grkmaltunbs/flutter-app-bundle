#!/usr/bin/env python3
"""Autobuild — headless autonomous runner for the Flutter app bundle.

Marches through PROJECT_PLAN.md unattended: for each pending step it spins up a
fresh Claude Agent SDK `query()` that follows `.claude/commands/step.md`
(implement → test → verify on iOS+Android simulators against fakes), then this
driver commits the verified step and pushes to main.

State lives in PROJECT_PLAN.md on disk — each step is an independent query()
(fresh context, cheaper, crash-resilient). The driver, not the model, owns git,
the budget, and the stop conditions.

Safety: the runner is deliberately STRICTER than an interactive session, because
nobody is watching. It runs `bypassPermissions` (so it never blocks on a prompt)
but a PreToolUse guardrail hook + a deny list still block destructive commands,
and the *agent* is forbidden from pushing — the driver does that deterministically.

Run:    caffeinate -i python3 runner/autobuild.py
Stop:   touch .autobuild-stop     (clean halt after the current step)

See docs/autobuild.md for full setup.
"""
from __future__ import annotations

import asyncio
import json
import os
import re
import shutil
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

from claude_agent_sdk import ClaudeAgentOptions, HookMatcher, query

# --------------------------------------------------------------------------- #
# Config (all overridable via environment variables)
# --------------------------------------------------------------------------- #
PROJECT_DIR = Path(os.environ.get("AUTOBUILD_PROJECT", ".")).resolve()
PLAN = PROJECT_DIR / "PROJECT_PLAN.md"
KILL_FILE = PROJECT_DIR / ".autobuild-stop"
LOG_FILE = PROJECT_DIR / "autobuild.log"
NEEDS_HUMAN_FILE = PROJECT_DIR / "AUTOBUILD_NEEDS_HUMAN.md"

MODEL = os.environ.get("AUTOBUILD_MODEL", "claude-opus-4-8")
MAX_TURNS = int(os.environ.get("AUTOBUILD_MAX_TURNS", "60"))
TOTAL_BUDGET_USD = float(os.environ.get("AUTOBUILD_BUDGET_USD", "50"))
MAX_CONSEC_FAILURES = int(os.environ.get("AUTOBUILD_MAX_FAILURES", "2"))
WALLCLOCK_HOURS = float(os.environ.get("AUTOBUILD_WALLCLOCK_HOURS", "8"))
# "main" | "branch:<name>" | "off"
PUSH = os.environ.get("AUTOBUILD_PUSH", "main")
FIREBASE_SA = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
SLACK_WEBHOOK = os.environ.get("AUTOBUILD_SLACK_WEBHOOK")

# Destructive command patterns the guardrail hook always denies — even though
# the interactive settings.json may allow them. Unattended runs get hard rails.
DESTRUCTIVE = [
    r"\brm\s+-rf\b",
    r"\bsudo\b",
    r"\bmkfs\b",
    r"\bdd\s+if=",
    r":\(\)\s*\{\s*:",            # fork bomb
    r"git\s+push\b",              # the DRIVER pushes, never the agent
    r"git\s+reset\s+--hard\b",
    r"firebase\s+deploy\b",       # prod deploys stay human-gated
    r">\s*/dev/sd",
]

ALLOWED_TOOLS = [
    "Read", "Edit", "Write", "Glob", "Grep", "Bash", "Task", "TodoWrite",
    "mcp__dart__*", "mcp__firebase__*",
]
# Glob-style deny (belt-and-suspenders with the regex hook).
DISALLOWED_TOOLS = [
    "Bash(sudo *)", "Bash(rm -rf *)",
    "Bash(git push *)", "Bash(git push --force *)", "Bash(git push -f *)",
    "Bash(git reset --hard *)", "Bash(firebase deploy *)",
]


# --------------------------------------------------------------------------- #
# Logging / notifications
# --------------------------------------------------------------------------- #
def _now() -> str:
    return datetime.now(timezone.utc).strftime("%H:%M:%S")


def log(msg: str) -> None:
    line = f"[{_now()}] {msg}"
    print(line, flush=True)
    with LOG_FILE.open("a") as fh:
        fh.write(line + "\n")


def notify(msg: str) -> None:
    log(msg)
    # macOS desktop notification (best-effort).
    if shutil.which("osascript"):
        subprocess.run(
            ["osascript", "-e", f'display notification {json.dumps(msg)} with title "autobuild"'],
            capture_output=True,
        )
    if SLACK_WEBHOOK and shutil.which("curl"):
        subprocess.run(
            ["curl", "-sS", "-X", "POST", "-H", "Content-Type: application/json",
             "-d", json.dumps({"text": f"autobuild: {msg}"}), SLACK_WEBHOOK],
            capture_output=True,
        )


# --------------------------------------------------------------------------- #
# Plan parsing — PROJECT_PLAN.md is the source of truth
# --------------------------------------------------------------------------- #
def parse_plan(text: str) -> list[dict]:
    steps: list[dict] = []
    for raw in re.split(r"(?m)^## Step ", text)[1:]:
        block = "## Step " + raw
        m_id = re.search(r"(?m)^- id:\s*(\S+)", block)
        if not m_id:
            continue
        sid = m_id.group(1).strip()
        done = bool(re.search(r"(?m)^- \[x\]", block))
        m_dep = re.search(r"(?m)^- depends_on:\s*(.+)$", block)
        deps_raw = (m_dep.group(1).strip() if m_dep else "none").lower()
        deps = (
            []
            if deps_raw in ("none", "-", "")
            else [d.strip() for d in re.split(r"[,\s]+", deps_raw) if d.strip()]
        )
        m_title = re.search(r"(?m)^## Step\s+(.+)$", block)
        title = m_title.group(1).strip() if m_title else sid
        steps.append({"id": sid, "done": done, "deps": deps, "title": title})
    return steps


def next_step(steps: list[dict]) -> dict | None:
    done_ids = {s["id"] for s in steps if s["done"]}
    for s in steps:
        if not s["done"] and all(d in done_ids for d in s["deps"]):
            return s
    return None


def is_done(step_id: str) -> bool:
    for s in parse_plan(PLAN.read_text()):
        if s["id"] == step_id:
            return s["done"]
    return False


# --------------------------------------------------------------------------- #
# Guardrail hook (PreToolUse on Bash)
# --------------------------------------------------------------------------- #
async def guardrail(input_data, tool_use_id, context):  # noqa: ANN001
    data = input_data or {}
    cmd = data.get("command") or data.get("tool_input", {}).get("command", "") or ""
    for pat in DESTRUCTIVE:
        if re.search(pat, cmd):
            log(f"⛔ guardrail denied: {cmd!r} (matched {pat!r})")
            return {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": f"autobuild guardrail: '{pat}' is not allowed unattended",
                }
            }
    return {}


# --------------------------------------------------------------------------- #
# MCP servers
# --------------------------------------------------------------------------- #
def mcp_servers() -> dict:
    servers = {"dart": {"type": "stdio", "command": "dart", "args": ["mcp-server"]}}
    if FIREBASE_SA:
        # NOTE: match this to your `claude mcp get firebase` invocation if it differs.
        servers["firebase"] = {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "firebase-tools", "experimental:mcp"],
            "env": {"GOOGLE_APPLICATION_CREDENTIALS": FIREBASE_SA},
        }
    else:
        log("⚠ GOOGLE_APPLICATION_CREDENTIALS unset — Firebase MCP disabled "
            "(the demo flavor uses fakes, so this is fine for building/verifying).")
    return servers


# --------------------------------------------------------------------------- #
# One step = one query()
# --------------------------------------------------------------------------- #
STEP_PROMPT = """You are running the bundle's /step workflow HEADLESSLY and unattended.

Read these files first: CLAUDE.md, PRODUCT_SPEC.md, PROJECT_PLAN.md, and
.claude/commands/step.md. Then implement step "{sid}" — "{title}" — following
.claude/commands/step.md EXACTLY:
- Delegate to the flutter-architect / flutter-developer / flutter-tester agents
  as that workflow specifies.
- Build the prod impls AND the demo-flavor fakes the flow needs.
- Verify with the flutter-qa agent on an iOS simulator AND an Android emulator,
  demo flavor (--dart-define=APP_ENV=demo). The step is only done when QA PASSES:
  zero runtime errors, zero overflow across the size matrix, all flows green.
- On PASS, flip this step's checkbox to [x] in PROJECT_PLAN.md (as step.md says).

Rules for unattended operation:
- NEVER wait for a human. Make sensible, spec-aligned decisions and proceed.
- Do NOT run any git command — the runner handles commits and pushes.
- If you hit a dependency only a human can satisfy (e.g. an App Store / Play /
  RevenueCat product that must be created, signing, a real API key), DO NOT fake
  past it: stop and report it as blocked with the exact items needed.

End your final message with EXACTLY one line of machine-readable JSON:
AUTOBUILD_RESULT: {{"step": "{sid}", "status": "completed|blocked|failed", "needs_human": ["..."], "summary": "one sentence"}}
"""


def parse_marker(text: str) -> dict | None:
    m = re.search(r"AUTOBUILD_RESULT:\s*(\{.*\})", text or "", re.S)
    if not m:
        return None
    try:
        return json.loads(m.group(1))
    except json.JSONDecodeError:
        return None


async def run_step(step: dict) -> dict:
    options = ClaudeAgentOptions(
        cwd=str(PROJECT_DIR),
        model=MODEL,
        max_turns=MAX_TURNS,
        setting_sources=["project"],          # loads settings.json, CLAUDE.md, agents
        permission_mode="bypassPermissions",  # deny rules + hooks still apply
        allowed_tools=ALLOWED_TOOLS,
        disallowed_tools=DISALLOWED_TOOLS,
        mcp_servers=mcp_servers(),
        hooks={"PreToolUse": [HookMatcher(matcher="Bash", hooks=[guardrail])]},
    )
    result = {"subtype": "error_during_execution", "cost": 0.0, "text": ""}
    prompt = STEP_PROMPT.format(sid=step["id"], title=step["title"])

    async for msg in query(prompt=prompt, options=options):
        cls = type(msg).__name__
        if cls == "AssistantMessage":
            for block in getattr(msg, "content", []) or []:
                txt = getattr(block, "text", None)
                if txt:
                    print(txt, end="", flush=True)
        elif cls == "ResultMessage" or getattr(msg, "type", None) == "result":
            result["subtype"] = getattr(msg, "subtype", None) or "unknown"
            result["cost"] = getattr(msg, "total_cost_usd", 0.0) or 0.0
            result["text"] = getattr(msg, "result", "") or ""
    print()
    return result


# --------------------------------------------------------------------------- #
# Git (the driver owns this — the agent is blocked from pushing)
# --------------------------------------------------------------------------- #
def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=PROJECT_DIR, capture_output=True, text=True)


def commit_and_push(step: dict) -> None:
    git("add", "-A")
    msg = (
        f"autobuild: step {step['id']} — {step['title']}\n\n"
        "Built and verified on iOS + Android simulators (demo flavor) by the "
        "autobuild runner.\n\n"
        "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
    )
    c = git("commit", "-m", msg)
    if c.returncode != 0:
        if "nothing to commit" in (c.stdout + c.stderr):
            log("…nothing to commit (step made no file changes?)")
            return
        log(f"⚠ commit failed: {c.stderr.strip()}")
        return
    if PUSH == "off":
        return
    if PUSH == "main":
        p = git("push", "origin", "main")
    elif PUSH.startswith("branch:"):
        p = git("push", "origin", f"HEAD:{PUSH.split(':', 1)[1]}")
    else:
        log(f"⚠ unknown AUTOBUILD_PUSH={PUSH!r}; skipping push")
        return
    log("…pushed" if p.returncode == 0 else f"⚠ push failed: {p.stderr.strip()}")


def record_needs_human(step: dict, items: list[str]) -> None:
    with NEEDS_HUMAN_FILE.open("a") as fh:
        fh.write(f"\n## Blocked at step `{step['id']}` ({step['title']}) — {_now()}\n")
        for it in items or ["(unspecified — see autobuild.log)"]:
            fh.write(f"- [ ] {it}\n")


# --------------------------------------------------------------------------- #
# Main loop
# --------------------------------------------------------------------------- #
async def main() -> None:
    if not PLAN.exists():
        log(f"✗ no PROJECT_PLAN.md at {PLAN}. Run /init-app first.")
        return

    start = time.time()
    spent = 0.0
    consec_failures = 0
    log(f"autobuild starting — model={MODEL}, budget=${TOTAL_BUDGET_USD}, push={PUSH}")

    while True:
        if KILL_FILE.exists():
            notify("⏹ .autobuild-stop present — halting cleanly")
            break
        if spent >= TOTAL_BUDGET_USD:
            notify(f"⏹ budget reached (${spent:.2f} ≥ ${TOTAL_BUDGET_USD}) — halting")
            break
        if (time.time() - start) / 3600.0 >= WALLCLOCK_HOURS:
            notify(f"⏹ wall-clock cap ({WALLCLOCK_HOURS}h) — halting")
            break

        step = next_step(parse_plan(PLAN.read_text()))
        if step is None:
            notify("✅ autobuild complete — all plan steps are [x]")
            break

        log(f"▶ step {step['id']} — {step['title']}")
        res = await run_step(step)
        spent += res["cost"]
        marker = parse_marker(res["text"]) or {}
        status = marker.get("status")
        done = is_done(step["id"])

        if done and status == "completed" and res["subtype"] == "success":
            commit_and_push(step)
            consec_failures = 0
            log(f"✓ {step['id']} done — step ${res['cost']:.2f}, total ${spent:.2f}")
        elif status == "blocked":
            record_needs_human(step, marker.get("needs_human", []))
            notify(f"⏸ blocked at {step['id']}: {marker.get('needs_human')} "
                   f"— see {NEEDS_HUMAN_FILE.name}. Halting for human action.")
            break
        else:
            consec_failures += 1
            log(f"✗ {step['id']} not verified (subtype={res['subtype']}, status={status}, "
                f"checkbox={'[x]' if done else '[ ]'}); failure {consec_failures}/{MAX_CONSEC_FAILURES}")
            if consec_failures >= MAX_CONSEC_FAILURES:
                notify(f"✗ halting after {consec_failures} consecutive failures at {step['id']}")
                break
            log("…retrying the same step with a fresh session")

    log(f"autobuild finished — total spend ${spent:.2f}")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        log("interrupted by user")
