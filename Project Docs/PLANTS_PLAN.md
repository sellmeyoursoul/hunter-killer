# Dodge the Creeps — Design doc (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:**  Introduce plants
**One-line objective:**  This phase will introduce a new element to the game. This is plants/food. 

**Out of scope (explicit non-goals):**  providing independence for mobs. At the moment, they don't experience hunger or non-linear movement
-  

---

## 2. Context for agents

**Repo / project root:**  `C:\Users\mikea\Documents\Git Proj\dodge-the-creeps` (authoritative for this repository clone; adjust `{projectHome}` if you open a copy elsewhere).
**Engine & version:**  Godot 4.6.2
**Main scenes / entry:**  Only one scene for this iteration
**Key scripts (paths):**  
    A. `{projectHome}/main.gd`
    B. `{projectHome}/player.gd`
    C. `{projectHome}/mob.gd`
    D. `{projectHome}/hud.gd`
    E. `{projectHome}/plant.gd`
-  

**Existing patterns to follow:** (naming, signals, groups, layers, file layout)  
    **formatting** 
    A. We are following the instructions in the `{projectHome}\.cursor\rules\instructions.md` file. From there apply Godot script best practices for GDScript. **C++:** No native C++ gameplay modules are in scope for this phase; if C++ is added later for TL inference glue, apply standard C++ practices then.
    B. We are going to comment every function we touch based on the documentation instructions in the `{projectHome}\.cursor\rules\instructions.md` file.
    c. Where possible we will use the same root names for the objects in different files. If there is a need to differentiate them add an `_` and a short descriptor (for example mobVariable_cpp and mobVariable_gd) 
-  

---

## 3. Requirements

### Must have
  A. Introduce a stationary object (plant), the goal of which is for the player to collide with
  B. Introduce the concept of hunger/calories, whith a new game_over() condition, starvation.
  C. Add a hunger indicator for players to observe. This reflects the current status of the new paramiter "calories". This number goes down every frame where the player moves (by one tick) and increases by an amout that is defined on each plant object. It is generated dynamically, but stays static for the object once instantiated.
-  

### Should have
-  

### Nice to have
-  

---

## 4. Technical design

### Architecture / data flow
(Diagram in words: who calls whom, new nodes, autoloads, resources.)

-  

### Scene & file changes
| Action | Path | Notes |
|--------|------|--------| 
| create | plant.gd | This defines the plant object
| modify | main.gd | instiantiate and display a plant object at a random location defined at the time the plant object is instatiated.
| create / modify / delete | `res://...` | |

### Collision / input / signals (if relevant)
- Layers/masks:  
- New signals:  
- Groups:  

### Dependencies
- Assets:  
- Plugins:  
- External APIs:  

---

## 5. Implementation plan (ordered)

1.  
2.  
3.  

---

## 6. Acceptance criteria

(Checklist — agent treats unchecked items as incomplete.)

- [ ]  
- [ ]  

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| | |

---

## 8. Testing / verification

**Manual steps:**  
-  

**Automated (if any):**  

---

## 9. Open questions

-  

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| | |
