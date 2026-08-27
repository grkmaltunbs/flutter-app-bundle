# Fixture — project plan

Format per step:

```
## Step N — <Title>
- [ ] <!-- this heading is inside a fence and must not become a step -->
- id: <kebab-slug>
```

---

## Step 0 — Bootstrap
- [x]
- id: bootstrap
- depends_on: none
- max_turns: 100

### Description

Set things up.

```
## Step 99 — Not a step, this is inside a fence
### Not a section either
```

### Acceptance
- It builds.

---

## Step G2 — Finish the notification engine
- [ ]
- id: notification-engine
- depends_on: bootstrap
- qa_required: true

### Description

Every push goes through one door.

**Your part (human) — the step's checkbox stays `[ ]` until these are checked:**

  - [x] ~~Approve the product defaults: cap 6/day.~~ **Approved 2026-08-21.**
  - [ ] On a **physical iPhone** receive one friend-request push end to end.
        Time it for **20:00–22:30 Europe/Istanbul**; later than that and quiet
        hours hold it.

Trailing paragraph after the boxes.

### Acceptance
- Pushes arrive.

### QA walkthrough
1. Send a nah.

---

## Step G12 — Weekly recap
- [ ]
- id: recap-winback
- depends_on: notification-engine, bootstrap

### Description

Depends on G2.

### Acceptance
- A recap goes out.
