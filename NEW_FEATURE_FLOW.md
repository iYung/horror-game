# New Feature Flow

How we ship features in this project. Each phase is a separate agent invocation.

---

## Overview

```
Design Agent → Checklist Agent → Task Agents (parallel) → Verification Agent
```

---

## Phase 1 — Design Agent

**Input:** A plain-English description of the feature.

**What it does:**
- Reads relevant parts of the codebase to understand what already exists
- Writes a design doc covering: motivation, what changes, what stays the same, any open questions

**Output:** `docs/design/<feature-name>.md`

Design doc structure:
```
## Goal
## Affected files
## What changes
## What stays the same
## Open questions
```

---

## Phase 2 — Checklist Agent

**Input:** The design doc from Phase 1.

**What it does:**
- Reads the design doc
- Breaks it into discrete, independently completable tasks
- Each task names the file(s) to touch and describes exactly what to do — no ambiguity

**Output:** `docs/checklists/<feature-name>.md`

Checklist structure:
```markdown
## <Feature Name> Checklist

- [ ] Task A — `path/to/file.lua` — what to add/change and why
- [ ] Task B — `path/to/other.lua` — what to add/change and why
...
```

Tasks should be small enough that one agent can finish one in a single session.

---

## Phase 3 — Task Agents

**Input:** The checklist from Phase 2.

**What it does:**
- Spawns one subagent per unchecked task
- Each subagent works on its task in isolation, reads only what it needs, and makes the change
- Subagents do not coordinate with each other — tasks must be independent enough for this to work

**Output:** Code changes. Each subagent marks its checklist item `[x]` when done.

If tasks have dependencies, run dependent ones sequentially rather than in parallel.

---

## Phase 4 — Verification Agent

**Input:** The checklist and all changed files.

**What it does:**
- Confirms every checklist item is marked done
- Reads each changed file and verifies the change matches the checklist description
- Runs any relevant tests or sanity checks
- Updates affected READMEs to reflect new or changed behaviour
- Moves the completed checklist to `docs/archive/<feature-name>.md`
- Moves the design doc to `docs/archive/design/<feature-name>.md`

If anything is incomplete or wrong, the verification agent flags it clearly rather than silently fixing it — fixes go back through the task agent phase.

---

## Folder layout

```
docs/
  design/       Active design docs (Phase 1 output)
  checklists/   Active checklists (Phase 2 output)
  archive/
    design/     Completed design docs
    <checklist> Completed checklists
```

---

## Rules

- Each agent gets its own fresh context. Docs are the handoff — write them clearly.
- Tasks in the checklist must be self-contained. If a task requires knowing what another task did, it is not ready to be parallelised.
- The verification agent is the only one that touches READMEs and the archive. Don't update docs mid-feature.
- Design docs are not implementation plans — they answer *what* and *why*, not *how line by line*. The checklist agent owns the how.
