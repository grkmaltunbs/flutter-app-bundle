# The plan schema

A project's plan is a directory:

```
plan/
├── kit.yaml            the project manifest
├── steps/<id>.yaml     one file per unit of Claude's work
└── items/<id>.yaml     one file per unit of the human's work
```

Two rules shape everything:

1. **An edge lives on the side that changes most.** Items are created and
   closed far more often than steps, so an *item* says which steps it
   `blocks:`; a step's human gate is computed from the items that name it.
   Nothing is stored twice, so nothing drifts.
2. **Stored state is minimal; display state is derived.** A step stores
   `pending | active | done`. Whether it is *blocked*, *ready*, *code
   complete* or *flippable* is worked out from dependencies, gates and items
   every time `kit` runs — so "the next step is 29" is never a sentence
   somebody has to remember to update.

`PROJECT_PLAN.md` and the board are **renderings** of this directory.
Regenerate them; never edit them.

## `kit.yaml`

```yaml
kit: 2
project: { name: Nahmatik, slug: nahmatik }
firebase: { project: nahmatik-1c548 }
qa: { runtime: ios-simulator, backend: live, screenshots: false, test_account_prefix: qa- }
platforms: [ios, android]
release_step: store-submission      # its blockers are launch blockers
board:
  title: Nahmatik Launch Board
  output: docs/board/launch_board.html
  artifact_url: https://claude.ai/code/artifact/…   # written by /board on first publish
  fonts: { display: Archivo Black, body: DM Sans, mono: JetBrains Mono }
  colors:
    light: { bg: "#FBF7F0", accent: "#1E5BFF", … }
    dark:  { bg: "#0E0B0A", accent: "#93AEFF", … }
plan_markdown: PROJECT_PLAN.md
journal: things_for_human_eye.md    # optional: the append-only prose journal
needs:                              # optional: extra kinds beyond the built-in eight
  lawyer: { label: A lawyer, description: Terms, privacy policy, consent copy. }
```

`qa` is free-form — the commands read it, the tool does not interpret it.
Colour tokens: `bg surface ink ink2 muted line accent accent_soft good
good_soft warn warn_soft critical critical_soft`; any you omit keep the kit
default.

## `steps/<id>.yaml`

```yaml
id: a11y-and-profile-privacy   # == file name; never changes
number: "29"                   # display only; headings move, ids do not
title: The app at 3.12x, and the half of a profile that isn't public
status: pending                # pending | active | done
rank: 700                      # work order (integers; leave gaps)
depends_on: [polish, security-hardening, living-home]
meta: { max_turns: 300, qa_required: true }   # passthrough
gates:                         # what Claude proves
  analyze: { status: passed, at: "2026-08-28" }
  tests:   { status: passed, at: "2026-08-28", note: "3103 tests" }
  qa:      { status: pending }
sections:                      # rendered in order as ### headings
  - { title: Description, body: | … }
  - { title: Acceptance,  body: | … }
  - { title: QA walkthrough, body: | … }
history:
  - { at: "2026-08-23", event: added, note: inserted between G13 and 26 }
  - { at: "2026-08-28", event: gate qa passed }
```

Gate names are free; `analyze`, `tests`, `qa` are the convention. A step
whose gates all pass while an item still `blocks:` it is **code complete** —
Claude's half is done, the user's is not — and `kit step done` refuses to
close it. That refusal is the feature.

A section body may contain the marker `<!-- kit:human-boxes -->`; the plan
renderer puts the step's items there as a checkbox list.

## `items/<id>.yaml`

```yaml
id: register-the-domain        # == file name
title: Register nahmatik.app and add it as a Hosting custom domain
status: open                   # open | done | dropped
needs: [console, money]        # the first one is the sitting it files under
blocks: [store-submission]     # steps that cannot close while this is open
step: app-links-invites        # provenance, not a gate
added: "2026-08-22"
deadline: "2026-10-30"         # only when the world imposes one
done_at: null
body: |
  Why this exists, what Claude cannot do about it, where the detail lives.
runbook:
  - do: Porkbun → buy the domain.
    expect: The domain shows in your account.
    if_fails: …
  - do: Firebase console → Hosting → Add custom domain.
    expect: Status "Connected" within an hour.
    verify: dig +short nahmatik.app
question:                      # decisions only; exactly one option recommended
  ask: Friends-only presence, or public and documented?
  options:
    - { label: Public, documented, recommended: true, why: 50 reads per screen otherwise }
    - { label: Friends-only, why: matches what was approved }
  answer: null
source: { file: things_for_human_eye.md, section: A. …, line: 66 }
note: …
```

### What an item can need

| kind | it means |
|---|---|
| `console` | Firebase, App Store Connect, Play, RevenueCat, a registrar — somewhere only your account can log in |
| `device` | a physical phone, or a second handset |
| `read` | copy in a language Claude drafted and nobody has read out loud |
| `look` | a visual sign-off a test cannot give |
| `decision` | a product, privacy or money call — Claude recommends, you decide |
| `store` | listings, TestFlight, review submissions, data-safety forms |
| `money` | a purchase, a domain, a paid plan |
| `secret` | keys and credentials that must never be in the repo |

## Derived states

| state | when |
|---|---|
| `done` | `status: done` |
| `blocked` | a dependency is not done |
| `ready` | pending, every dependency done |
| `active` | `status: active`, a gate still pending |
| `code complete` | active, every gate passed, an item still blocks it |
| `flippable` | active, every gate passed, nothing blocks it — run `kit step done` |

`kit next` is the active step if there is one, else the first ready step by
rank. An item is **decisive** when it is among the last things blocking a
code-complete step; the board lists those first. Urgency on the board:
dated deadlines, then decisive items, then items gating the release path,
then items gating anything, then the rest — oldest first inside each group.

## Invariants `kit validate` enforces

- ids match file names; `depends_on` and `blocks` name real steps; no cycles;
- a `done` step has no open item blocking it (**error** — a step is not done
  while its boxes are open);
- a question recommends exactly one option;
- `needs` are known kinds;
- a `release_step` exists.

## Commands

```
kit validate · status · next [--step] · show <id> · blocks <step>
kit gate <step> <gate> passed|failed|pending [--note]
kit step start|done <step> [--force]
kit done|drop|reopen <item> [--note]
kit item new --id --title [--needs] [--blocks] [--from <step>] [--deadline] [--body|--body-file]
kit render plan|board [--out]
kit import --plan-md PROJECT_PLAN.md [--journal file] --out plan --name N [--release-step id] [--active a,b]
kit init --name N
```

`kit import` is the migration from a hand-written `PROJECT_PLAN.md` and a
journal of `- [ ]` boxes. It is lossless on prose and heuristic on the fields
nobody wrote down (`needs`, `blocks`, `added`); what it could not tell, it
leaves empty and lists, and the board shows those under "could not sort".
