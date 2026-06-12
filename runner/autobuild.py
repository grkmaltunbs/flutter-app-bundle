#!/usr/bin/env python3
"""Autobuild — headless autonomous runner for the Flutter app bundle.

Marches through PROJECT_PLAN.md unattended: for each pending step it spins up a
fresh Claude Agent SDK `query()` that invokes the project's `/step` slash command
natively — setting_sources=["project"] loads `.claude/commands/step.md` —
(implement → test → verify on iOS+Android simulators against fakes), then this
driver commits the verified step and pushes to main.

State lives in PROJECT_PLAN.md on disk — each step is an independent query()
(fresh context, cheaper, crash-resilient). The driver, not the model, owns git,
the budget, and the stop conditions.

Safety: the runner is deliberately STRICTER than an interactive session, because
nobody is watching. It runs `bypassPermissions` (so it never blocks on a prompt)
but a PreToolUse guardrail hook + a deny list still block destructive commands,
and the *agent* is forbidden from committing or pushing — the driver does both
deterministically.

Run:    caffeinate -i runner/.venv/bin/python runner/autobuild.py
Stop:   touch .autobuild-stop     (clean halt after the current step)
        Ctrl-C / `kill <pid>` (SIGTERM) also halt cleanly.

See docs/autobuild.md for full setup.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import shutil
import signal
import subprocess
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path

# The Claude Agent SDK is imported lazily inside run_step() so that --help,
# argument parsing, and plan inspection work before the SDK is installed.

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
STEP_TIMEOUT_MIN = float(os.environ.get("AUTOBUILD_STEP_TIMEOUT_MIN", "120"))  # per-step ceiling
# "main" | "branch:<name>" | "off"
PUSH = os.environ.get("AUTOBUILD_PUSH", "main")
FIREBASE_SA = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
SLACK_WEBHOOK = os.environ.get("AUTOBUILD_SLACK_WEBHOOK")

# Destructive command patterns the guardrail hook always denies — even though
# the interactive settings.json may allow them. Unattended runs get hard rails.
DESTRUCTIVE = [
    # (recursive+force rm is handled by a dedicated check in guardrail() — it
    # catches every flag spelling/order, not just the literal "-rf")
    r"\bsudo\b",
    r"\bmkfs\b",
    r"\bdd\s+if=",
    r":\(\)\s*\{\s*:",            # fork bomb
    r"git\s+push\b",              # the DRIVER pushes, never the agent
    r"git\s+reset\s+--hard\b",
    r"git\s+(commit|add|rebase|merge)\b",  # the driver owns git history
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
    "Bash(git reset --hard *)", "Bash(git commit *)", "Bash(git add *)",
    "Bash(firebase deploy *)",
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
    # Drop fenced code blocks first — the shipped plan template shows the step
    # FORMAT inside a ``` fence, which would otherwise parse as a phantom step.
    kept: list[str] = []
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            kept.append(line)
    cleaned = "\n".join(kept)

    steps: list[dict] = []
    for raw in re.split(r"(?m)^## Step ", cleaned)[1:]:
        block = "## Step " + raw
        m_id = re.search(r"(?m)^- id:\s*(\S+)", block)
        if not m_id:
            continue
        sid = m_id.group(1).strip()
        # Done = the step's OWN checkbox — the FIRST one in the block — is
        # checked ([x] or [X]). A stray [x] elsewhere in the block doesn't count.
        m_box = re.search(r"(?m)^- \[([ xX])\]", block)
        done = bool(m_box) and m_box.group(1).lower() == "x"
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
    # rm with BOTH a recursive flag and a force flag — any spelling, order, or
    # clustering (-rf, -fR, -r -f, --recursive --force, …) — is denied outright.
    if (
        re.match(r"\s*rm\b", cmd)
        and re.search(r"(^|\s)-{1,2}[^\s]*([rR]|recursive)", cmd)
        and re.search(r"(^|\s)-{1,2}[^\s]*(f|force)", cmd)
    ):
        log(f"⛔ guardrail denied: {cmd!r} (recursive+force rm)")
        return {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": "autobuild guardrail: recursive+force rm is not allowed unattended",
            }
        }
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
            "args": ["-y", "firebase-tools", "mcp"],
            "env": {"GOOGLE_APPLICATION_CREDENTIALS": FIREBASE_SA},
        }
    else:
        log("⚠ GOOGLE_APPLICATION_CREDENTIALS unset — Firebase MCP disabled "
            "(the demo flavor uses fakes, so this is fine for building/verifying).")
    return servers


# --------------------------------------------------------------------------- #
# One step = one query()
# --------------------------------------------------------------------------- #
# The /step slash command itself is invoked natively (prompt = "/step <id>");
# these unattended rules + the AUTOBUILD_RESULT marker contract ride along as a
# system-prompt append on top of the claude_code preset.
UNATTENDED_RULES = """You are running the bundle's /step workflow HEADLESSLY and unattended.

Rules for unattended operation:
- NEVER wait for a human. Make sensible, spec-aligned decisions and proceed.
- Do NOT run any git command that mutates state (add, commit, push, reset,
  rebase, merge, tag) — the runner owns commits and pushes. Read-only git
  (status, diff, log, show) is fine.
- If you hit a dependency only a human can satisfy (e.g. an App Store / Play /
  RevenueCat product that must be created, signing, a real API key), DO NOT fake
  past it: stop and report it as blocked with the exact items needed.

End your final message with EXACTLY one line of machine-readable JSON:
AUTOBUILD_RESULT: {{"step": "{sid}", "status": "completed|blocked|failed", "needs_human": ["..."], "summary": "one sentence"}}
"""


def parse_marker(text: str) -> dict | None:
    # Line-anchored scan first: the contract says ONE line of JSON, and the
    # marker JSON has no nested objects, so a non-greedy {...} is safe. Take
    # the LAST occurrence (agents sometimes quote the contract before emitting
    # the real marker).
    matches = re.findall(r"(?m)^\s*AUTOBUILD_RESULT:\s*(\{.*?\})\s*$", text or "")
    if matches:
        try:
            return json.loads(matches[-1])
        except json.JSONDecodeError:
            pass
    # Fallback: the old greedy single-shot scan (marker mid-line / trailing prose).
    m = re.search(r"AUTOBUILD_RESULT:\s*(\{.*\})", text or "", re.S)
    if not m:
        return None
    try:
        return json.loads(m.group(1))
    except json.JSONDecodeError:
        return None


async def run_step(step: dict) -> dict:
    try:
        from claude_agent_sdk import ClaudeAgentOptions, HookMatcher, query
    except ImportError as exc:
        raise SystemExit(
            "claude-agent-sdk is not installed. Activate your venv and run:\n"
            "    pip install -r runner/requirements.txt\n"
            "(The Claude Code CLI must also be installed and authenticated.)"
        ) from exc

    options = ClaudeAgentOptions(
        cwd=str(PROJECT_DIR),
        model=MODEL,
        max_turns=MAX_TURNS,
        setting_sources=["project"],          # loads settings.json, CLAUDE.md, agents, slash commands
        system_prompt={"type": "preset", "preset": "claude_code",
                       "append": UNATTENDED_RULES.format(sid=step["id"])},
        permission_mode="bypassPermissions",  # deny rules + hooks still apply
        allowed_tools=ALLOWED_TOOLS,
        disallowed_tools=DISALLOWED_TOOLS,
        mcp_servers=mcp_servers(),
        hooks={"PreToolUse": [HookMatcher(matcher="Bash", hooks=[guardrail])]},
    )
    result = {"subtype": "error_during_execution", "cost": 0.0, "text": ""}
    # Invoke the project's /step slash command natively — setting_sources above
    # is what makes the SDK load .claude/commands/step.md.
    prompt = f"/step {step['id']}"

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


def _commit_message(step: dict) -> str:
    return (
        f"autobuild: step {step['id']} — {step['title']}\n\n"
        "Built and verified on a simulator (demo flavor) by the autobuild "
        "runner.\n\n"
        f"Co-Authored-By: Claude ({MODEL}) <noreply@anthropic.com>"
    )


def commit_and_push(step: dict, push: str, pre_head: str) -> None:
    git("add", "-A")
    c = git("commit", "-m", _commit_message(step))
    if c.returncode != 0:
        if "nothing to commit" in (c.stdout + c.stderr):
            if git("rev-parse", "HEAD").stdout.strip() == pre_head:
                log("…nothing to commit (step made no file changes?)")
                return
            # HEAD moved despite the rails — the agent made its own commit.
            # Don't strand it locally; proceed to push it.
            log("…nothing to commit, but HEAD moved — the agent committed on its own; pushing that commit")
        else:
            log(f"⚠ commit failed: {c.stderr.strip()}")
            return
    if push == "off":
        log("…committed (push disabled)")
        return
    if push == "main":
        # Push the actual checkout, not a possibly-stale local main ref.
        p = git("push", "origin", "HEAD:main")
    elif push.startswith("branch:"):
        p = git("push", "origin", f"HEAD:{push.split(':', 1)[1]}")
    else:
        log(f"⚠ unknown push target {push!r}; committed but not pushed")
        return
    log("…committed + pushed" if p.returncode == 0 else f"⚠ push failed: {p.stderr.strip()}")


def restore_worktree(reason: str) -> None:
    """Throw away the attempt's uncommitted changes so retries start clean and
    halts leave a clean repo. (`git clean -fd` skips gitignored files, so
    autobuild.log / AUTOBUILD_NEEDS_HUMAN.md survive.)"""
    git("checkout", "--", ".")
    git("clean", "-fd")
    log(f"…working tree restored ({reason})")


def push_preflight(push: str) -> str:
    """Sanity-check the push target ONCE at startup, before burning budget.
    Downgrades to 'off' (with a loud notify) instead of failing mid-run."""
    if push == "off":
        return push
    origin = git("remote", "get-url", "origin")
    if origin.returncode != 0:
        notify("⚠ push preflight: no 'origin' remote — downgrading push to off")
        return "off"
    url = origin.stdout.strip()
    if "flutter-app-bundle" in url:
        notify(f"⚠ push preflight: origin is the BUNDLE repo ({url}) — refusing to "
               "push app commits there; downgrading push to off")
        return "off"
    if push == "main":
        refspec = "HEAD:main"
    elif push.startswith("branch:"):
        refspec = f"HEAD:{push.split(':', 1)[1]}"
    else:
        notify(f"⚠ push preflight: unknown push target {push!r} — downgrading push to off")
        return "off"
    p = git("push", "--dry-run", "origin", refspec)
    if p.returncode != 0:
        notify(f"⚠ push preflight: `git push --dry-run origin {refspec}` failed "
               f"({p.stderr.strip()}) — downgrading push to off")
        return "off"
    log(f"…push preflight OK (origin={url}, refspec={refspec})")
    return push


def dry_run_report(step: dict, push: str) -> None:
    """Show what a real run WOULD commit — without touching git."""
    log("🧪 DRY RUN — not committing or pushing. Working-tree changes:")
    status = git("status", "--short").stdout.rstrip()
    print(status or "  (no file changes)")
    stat = git("diff", "--stat").stdout.rstrip()
    if stat:
        print(stat)
    log(f"Would commit as: {_commit_message(step).splitlines()[0]!r}")
    log("Would push to: (disabled in dry-run)" if push == "off" else f"Would push to: {push}")


def record_needs_human(step: dict, items: list[str]) -> None:
    with NEEDS_HUMAN_FILE.open("a") as fh:
        fh.write(f"\n## Blocked at step `{step['id']}` ({step['title']}) — {_now()}\n")
        for it in items or ["(unspecified — see autobuild.log)"]:
            fh.write(f"- [ ] {it}\n")


# --------------------------------------------------------------------------- #
# Main loop
# --------------------------------------------------------------------------- #
def select_step(args) -> dict | None | str:
    """Return the step to run, None if there's nothing to do, or 'missing'."""
    steps = parse_plan(PLAN.read_text())
    if args.step:
        step = next((s for s in steps if s["id"] == args.step), None)
        if step is None:
            return "missing"
        if step["done"]:
            log(f"⚠ step {args.step} is already [x] — running it anyway (requested).")
        unmet = [d for d in step["deps"] if not is_done(d)]
        if unmet:
            log(f"⚠ step {args.step} has unmet deps {unmet} — proceeding because --step was explicit.")
        return step
    return next_step(steps)


async def main(args) -> None:
    if not PLAN.exists():
        log(f"✗ no PROJECT_PLAN.md at {PLAN}. Run /init-app first.")
        return

    push = "off" if args.no_push else PUSH
    if push != "off" and not args.dry_run:
        push = push_preflight(push)
    single = args.once or args.dry_run or bool(args.step)
    mode = "DRY RUN" if args.dry_run else ("single-step" if single else "full loop")
    start = time.time()
    spent = 0.0
    consec_failures = 0
    log(f"autobuild starting — mode={mode}, model={MODEL}, budget=${TOTAL_BUDGET_USD}, "
        f"push={'off (dry-run)' if args.dry_run else push}")

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

        step = select_step(args)
        if step == "missing":
            log(f"✗ no step with id {args.step!r} in PROJECT_PLAN.md")
            break
        if step is None:
            # Nothing runnable. That's only success if nothing is PENDING —
            # otherwise the remaining steps have unmet/orphaned depends_on.
            pending = [s for s in parse_plan(PLAN.read_text()) if not s["done"]]
            if pending:
                ids = ", ".join(s["id"] for s in pending)
                notify(f"⚠ {len(pending)} pending step(s) are unrunnable "
                       f"(unmet or orphaned depends_on): {ids}")
                break
            notify("✅ autobuild complete — all plan steps are [x]")
            break

        pre_head = git("rev-parse", "HEAD").stdout.strip()
        log(f"▶ step {step['id']} — {step['title']}")
        remaining_wallclock = WALLCLOCK_HOURS * 3600.0 - (time.time() - start)
        try:
            res = await asyncio.wait_for(
                run_step(step),
                timeout=max(60, min(STEP_TIMEOUT_MIN * 60, remaining_wallclock)),
            )
        except asyncio.TimeoutError:
            log(f"✗ step {step['id']} hit the per-step timeout "
                f"(AUTOBUILD_STEP_TIMEOUT_MIN={STEP_TIMEOUT_MIN:g})")
            res = {"subtype": "timeout", "cost": 0.0, "text": ""}
        except Exception:  # KeyboardInterrupt/SystemExit are BaseException — not caught
            log(f"✗ step {step['id']} raised:\n{traceback.format_exc()}")
            res = {"subtype": "exception", "cost": 0.0, "text": ""}
        spent += res["cost"]
        marker = parse_marker(res["text"])
        if marker is None and res["subtype"] == "success" and is_done(step["id"]):
            log("⚠ marker unparseable; trusting checkbox + success subtype")
            marker = {"status": "completed"}
        marker = marker or {}
        status = marker.get("status")
        done = is_done(step["id"])
        verified = status == "completed" and res["subtype"] == "success" and done

        if verified:
            if args.dry_run:
                dry_run_report(step, push)
            else:
                commit_and_push(step, push, pre_head)
            consec_failures = 0
            log(f"✓ {step['id']} — step ${res['cost']:.2f}, total ${spent:.2f}")
        elif status == "blocked":
            record_needs_human(step, marker.get("needs_human", []))
            if not args.dry_run:
                restore_worktree("blocked — leaving a clean repo for the human")
            notify(f"⏸ blocked at {step['id']}: {marker.get('needs_human')} "
                   f"— see {NEEDS_HUMAN_FILE.name}. Halting for human action.")
            break
        else:
            consec_failures += 1
            log(f"✗ {step['id']} not verified (subtype={res['subtype']}, status={status}, "
                f"checkbox={'[x]' if done else '[ ]'}); failure {consec_failures}/{MAX_CONSEC_FAILURES}")
            if not args.dry_run:
                restore_worktree("step not verified — retries start clean")
            if consec_failures >= MAX_CONSEC_FAILURES:
                notify(f"✗ halting after {consec_failures} consecutive failures at {step['id']}")
                break
            if single:
                log("…single-step mode — not retrying.")
                break
            log("…retrying the same step with a fresh session")
            continue

        if single:
            break

    log(f"autobuild finished — total spend ${spent:.2f}")


def parse_args():
    p = argparse.ArgumentParser(
        description="Autobuild — headless autonomous runner for the Flutter app bundle.")
    p.add_argument("--dry-run", action="store_true",
                   help="Run ONE step but do not commit or push; print what it would commit. "
                        "Leaves the implemented changes in the working tree for inspection.")
    p.add_argument("--once", action="store_true",
                   help="Process exactly one step (commit + push as configured), then exit.")
    p.add_argument("--step", metavar="ID",
                   help="Target a specific step id (implies single-step; runs even if deps are unmet).")
    p.add_argument("--no-push", action="store_true",
                   help="Commit but never push (overrides AUTOBUILD_PUSH).")
    return p.parse_args()


def _sigterm(signum, frame):  # noqa: ANN001
    # Translate `kill <pid>` into the same clean halt path as Ctrl-C.
    raise KeyboardInterrupt


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, _sigterm)
    try:
        asyncio.run(main(parse_args()))
    except KeyboardInterrupt:
        notify("⏹ interrupted (Ctrl-C / SIGTERM) — halted")
    except Exception as exc:  # noqa: BLE001
        notify(f"✗ autobuild crashed: {exc}")
        raise
