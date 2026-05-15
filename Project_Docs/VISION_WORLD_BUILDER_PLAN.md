# Hunter Killer — World Builder vision (umbrella doc, agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:** World Builder — program vision (non-implementing umbrella)

**One-line objective:** Capture the long-range goal of a **World Builder** stack: iterate from small Godot games toward an MMORPG where NPCs and the environment interact credibly, with data-driven creatures, plants, and terrain—without committing this repo to full MMO scope in early phases.

**Out of scope (explicit non-goals):**  
- Shipping an MMO from this repository in a single phase.  
- Replacing physics with LLM-driven motor control (see **§3** and [AI_INT_CONVERSATION_SCOPE_PLAN.md](AI_INT_CONVERSATION_SCOPE_PLAN.md)).  
- Locking network architecture until a dedicated networking phase exists.

---

## 2. Context for agents

**Repo / project root:** `{projectHome}/hunter-killer` (directory containing `project.godot`; adjust per clone).

**Engine & version:** Godot 4.6.2

**Main scenes / entry:** Current entry remains Dodge-the-Creeps–style scenes; future “world” scenes will be named in child feature plans.

**Key scripts (paths):** TBD per phase; see active feature plans below.

**Existing patterns to follow:**  
- Follow [`.cursor/rules/AGENTS.md`](../.cursor/rules/AGENTS.md) and [`.cursor/rules/focus/`](../.cursor/rules/focus/).  
- **Feature-doc scope:** When implementing a ticket, the **explicitly referenced** feature plan is authoritative; this vision doc does not override a narrower phase doc.

**Split from legacy notes:** The freeform capture in [EARLY_SPEC_DOC](EARLY_SPEC_DOC) is superseded for **agent work** by the linked plans below; keep EARLY_SPEC_DOC as historical scratch or index.

---

## 3. Requirements

### Must have (for this *document* phase only)

- A **single index** of world-model feature plans so contributors can extend design before code.  
- Clear statement: **creature locomotion and tactical movement** use **engine/heuristic/utility** approaches; **remote LLM (TinyLlama) integration remains optional** for non-real-time uses (see conversation scope plan).

### Should have

- Each child plan uses [FEATURE_PLAN_TEMPLATE.md](FEATURE_PLAN_TEMPLATE.md) sections so implementation passes stay consistent.

### Nice to have

- Diagrams (Mermaid) in child plans when architecture stabilizes.

---

## 4. Technical design

### Architecture / data flow

- **Vision layer (this file):** Roadmap and cross-links only.  
- **Domain plans:** [CREATURE_MODEL_PLAN.md](CREATURE_MODEL_PLAN.md), [PLANT_ECOLOGY_PLAN.md](PLANT_ECOLOGY_PLAN.md), [ENVIRONMENT_MODEL_PLAN.md](ENVIRONMENT_MODEL_PLAN.md), [SHARED_STATTOPOINT_PLAN.md](SHARED_STATTOPOINT_PLAN.md).  
- **Near-term gameplay:** [PLANTS_PLAN.md](PLANTS_PLAN.md) (player food / starvation POC).  
- **LLM posture:** [AI_INT_CONVERSATION_SCOPE_PLAN.md](AI_INT_CONVERSATION_SCOPE_PLAN.md).

### Scene & file changes

| Action | Path | Notes |
|--------|------|-------|
| n/a | — | No code changes required to satisfy this umbrella doc. |

### Collision / input / signals (if relevant)

- Deferred to child plans.

### Dependencies

- None for documentation-only milestone.

---

## 5. Implementation plan (ordered)

1. Keep child feature docs updated as POCs land (plants, larger playfield, etc.).  
2. When adding a new domain (e.g. predators), add a new `*_PLAN.md` from the template and link it here and in EARLY_SPEC_DOC index.

---

## 6. Acceptance criteria

- [ ] This file lists all active world-model plans with relative links (see §4).  
- [ ] EARLY_SPEC_DOC begins with a pointer to this file and the child plans.  
- [ ] LLM “not the movement engine” policy is stated in §1 or §3 and mirrored in AI conversation scope plan.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Vision doc overrides narrow phase specs | AGENTS.md scope guard: only referenced plan is normative for an implementation task. |
| Over-building abstractions before gameplay | Child plans mark **POC subset** vs **future field** explicitly. |

---

## 8. Testing / verification

**Manual steps:**  
- Review links from this file in GitHub / editor preview.

**Automated (if any):**  
- None.

---

## 9. Open questions

- <<Question: When do we split “player” vs “generic Creature” in code—first autonomous NPC phase or earlier via shared Resource?>>

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 2026-05-11 | Initial split from EARLY_SPEC_DOC; umbrella vision + links. |
