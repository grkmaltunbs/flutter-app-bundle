---
name: kit-codex-setup
description: "Put the flutter-kit agents and rules in place for Codex in this project: the agent profiles into .codex/agents/, CLAUDE.md as the instructions file, the Dart MCP server."
---

> **Where things are.** This file is `skills/kit-codex-setup/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Set `PLUGIN` to that root in the shell.

# $kit-codex-setup — flutter-kit in Codex, for this project

Run, in the project folder:

```bash
bash "$PLUGIN/tool/codex/setup.sh" "$PWD"
```

It does four things, each only where it is missing, and prints what it did:

1. copies the nine agent profiles from `$PLUGIN/assets/agents/*.toml` into `.codex/agents/` (flutter-architect, flutter-developer, flutter-debugger, flutter-refactorer, flutter-releaser, flutter-reviewer, flutter-tester, flutter-qa, flutter-ui-designer) — Codex plugins carry no agents yet, so the project holds them;
2. sets `project_doc_fallback_filenames = ["CLAUDE.md"]` at the top of `.codex/config.toml`, so Codex reads the project's `CLAUDE.md` where it would read `AGENTS.md` (if the project also has an `AGENTS.md`, that one wins and the two drift — one file is better);
3. says whether Codex **trusts** the folder: a project's own `.codex/config.toml` is read only once it does (proven 2026-09-10), so until then the fallback and the Dart server entry do nothing — trusting is the user's: open `codex` in the folder once and accept, or add `[projects."<absolute path>"]` `trust_level = "trusted"` to `~/.codex/config.toml`;
4. says whether the Dart MCP server is configured for Codex (`codex mcp list`) and, if not, the one command that adds it: `codex mcp add dart -- dart mcp-server`.

Then tell the user the two things only they can do: trust the folder if the script said it is not, and trust the plugin's hooks once (`/hooks` in the Codex TUI) — until then the phone's "now" line stays empty under Codex. A thread's `thread/start` reply lists what Codex loaded as `instructionSources`; empty means no rules.
