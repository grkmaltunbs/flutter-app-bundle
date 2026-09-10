#!/usr/bin/env python3
"""The plugin's second home: the 19 commands as Codex skills and the 9
agents as Codex agent profiles, generated from commands/ and agents/.

    python3 tool/codex/generate.py        # writes skills/kit-*/SKILL.md and assets/agents/*.toml

Codex discovers a plugin's `skills/` and invokes one as `$name`; it reads
neither `commands/` nor `agents/`, and it substitutes nothing in a skill's
text (`${CLAUDE_PLUGIN_ROOT}` is set for hooks only), so every path is
written relative to the plugin root the preamble names. The skills carry a
`kit-` prefix so Claude Code, which reads `skills/` too, does not see a
skill and a command under one name.
"""
import json, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
COMMANDS = os.path.join(ROOT, "commands")
AGENTS = os.path.join(ROOT, "agents")
SKILLS = os.path.join(ROOT, "skills")
ASSETS = os.path.join(ROOT, "assets", "agents")

NAMES = sorted(f[:-3] for f in os.listdir(COMMANDS) if f.endswith(".md"))
AGENT_NAMES = sorted(f[:-3] for f in os.listdir(AGENTS) if f.endswith(".md"))
READ_ONLY = {"flutter-architect", "flutter-reviewer", "flutter-qa"}

PREAMBLE = """> **Where things are.** This file is `skills/kit-{name}/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Before anything else set, in the shell, `PLUGIN` to that root (Claude Code: `${{CLAUDE_PLUGIN_ROOT}}`) and `KIT="$PLUGIN/kit/kit.sh"`; every `kit` command below runs as `bash "$KIT" …`, in the project folder. `$ARGUMENTS` means the words after `$kit-{name}` in the user's message. Agents named in bold (flutter-tester, flutter-qa, …) are the Codex custom agents `$kit-codex-setup` installs into the project's `.codex/agents/`; spawn them by name, and where one is not installed do that part yourself.

"""

def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}, text
    fm = {}
    for line in m.group(1).split("\n"):
        k, _, v = line.partition(":")
        if k.strip():
            fm[k.strip()] = v.strip()
    return fm, text[m.end():]

def to_skill(name, body):
    b = body
    b = b.replace('bash "${CLAUDE_PLUGIN_ROOT}/kit/kit.sh"', 'bash "$KIT"')
    b = b.replace("bash ${CLAUDE_PLUGIN_ROOT}/kit/kit.sh", 'bash "$KIT"')
    b = b.replace("${CLAUDE_PLUGIN_ROOT}", "$PLUGIN")
    names = "|".join(re.escape(n) for n in NAMES)
    b = re.sub(r"(?<![\w./`-])/(" + names + r")\b", r"$kit-\1", b)
    b = re.sub(r"`/(" + names + r")\b", r"`$kit-\1", b)
    b = b.replace("# /" + name, "# $kit-" + name, 1)
    return b

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)

def yaml_str(s):
    return json.dumps(s, ensure_ascii=False)

def main():
    made = []
    for name in NAMES:
        text = open(os.path.join(COMMANDS, name + ".md")).read()
        fm, body = frontmatter(text)
        desc = fm.get("description", name)
        out = "---\nname: kit-%s\ndescription: %s\n---\n\n%s%s" % (name, yaml_str(desc), PREAMBLE.format(name=name), to_skill(name, body))
        write(os.path.join(SKILLS, "kit-" + name, "SKILL.md"), out)
        made.append("skills/kit-%s/SKILL.md" % name)
    # The setup skill: the agents into .codex/agents/, CLAUDE.md as the instructions file.
    setup = """---
name: kit-codex-setup
description: "Put the flutter-kit agents and rules in place for Codex in this project: the agent profiles into .codex/agents/, CLAUDE.md as the instructions file, the Dart MCP server."
---

> **Where things are.** This file is `skills/kit-codex-setup/SKILL.md` inside the flutter-kit plugin; the plugin root is two folders above it. Set `PLUGIN` to that root in the shell.

# $kit-codex-setup — flutter-kit in Codex, for this project

Run, in the project folder:

```bash
bash "$PLUGIN/tool/codex/setup.sh" "$PWD"
```

It does three things, each only where it is missing, and prints what it did:

1. copies the nine agent profiles from `$PLUGIN/assets/agents/*.toml` into `.codex/agents/` (flutter-architect, flutter-developer, flutter-debugger, flutter-refactorer, flutter-releaser, flutter-reviewer, flutter-tester, flutter-qa, flutter-ui-designer) — Codex plugins carry no agents yet, so the project holds them;
2. sets `project_doc_fallback_filenames = ["CLAUDE.md"]` in `.codex/config.toml`, so Codex reads the project's `CLAUDE.md` where it would read `AGENTS.md`;
3. says whether the Dart MCP server is configured for Codex (`codex mcp list`) and, if not, the one command that adds it: `codex mcp add dart -- dart mcp-server`.

Then tell the user the one thing only they can do: the plugin's hooks run in Codex only after they have reviewed and trusted them once (`/hooks` in the Codex TUI); until then the phone's "now" line stays empty under Codex.
"""
    write(os.path.join(SKILLS, "kit-codex-setup", "SKILL.md"), setup)
    made.append("skills/kit-codex-setup/SKILL.md")
    for name in AGENT_NAMES:
        text = open(os.path.join(AGENTS, name + ".md")).read()
        fm, body = frontmatter(text)
        desc = fm.get("description", name)
        instructions = body.strip().replace('"""', '\\"\\"\\"')
        toml = 'name = %s\ndescription = %s\n' % (json.dumps(fm.get("name", name), ensure_ascii=False), json.dumps(desc, ensure_ascii=False))
        if name in READ_ONLY:
            toml += 'sandbox_mode = "read-only"\n'
        toml += 'developer_instructions = """\n%s\n"""\n' % instructions
        write(os.path.join(ASSETS, name + ".toml"), toml)
        made.append("assets/agents/%s.toml" % name)
    print("\n".join(made))

if __name__ == "__main__":
    main()
