# Dodge the Creeps — Design doc (agent-friendly)

> Fill each section before implementation. Keep bullets concrete enough that an agent can open the right files and know when it is done.

---

## 1. Phase summary

**Phase name:**  Ai Integration
**One-line objective:**  This is where we plug TinyLlama into the game and allow it to take on the role of the player

**Out of scope (explicit non-goals):**  We are not going to add any AI logic to the MOBs or change any of the fundamental game logic
-  

---

## 2. Context for agents

**Repo / project root:**  "C:\Users\mikea\Documents\Proj Git Repo\Dodge the creeps"
**Engine & version:**  Godot 4.6.2
**Main scenes / entry:**  Only one scene for this iteration
**Key scripts (paths):**  
    A. {projectHome}/dodge-the-creeps/main.gd
    B. {projectHome}/dodge-the-creeps/Player.gd
    C. {projectHome}/dodge-the-creeps/mob.gd
    D. {projectHome}/dodge-the-creeps/hud.gd
-  

**Existing patterns to follow:** (naming, signals, groups, layers, file layout)  
    **formatting** 
    A. We are following the instructions in the "{projectHome}\dodge-the-creeps\.cursor\rules\instructions.md" file. From there apply Godot script best practices for the GDScript and C++ best practices for the C++ code. 
    B. We are going to comment every function we touch based on the documentation instructions in the "{projectHome}\dodge-the-creeps\.cursor\rules\instructions.md" file.
    c. Where possible we will use the same root names for the objects in different files. If there is a need to differentate them add an _ and a short descriptor (for example mobVariable_cpp and mobVariable_gd)

-  

---

## 3. Requirements

### Must have
    A. TinyLlama (TL) must be able to interact with the application as a player at runtime.
    B. TL must be able to use the keypad enter key to start the game.
    C. TL must be able to singnal the use of the up arrow key to move up, the down arrow key to move down, the left arrow key to move left, and the right arrow key to move right.
    This Action parse should be done by returning a single token for the key it choses to press to minimize load.
    D. TL is instructed that the point of the game is to avoid collisions for as long as possible within the confines of the four available direction keys and the bounds of screen.

<<Question: Injection vs simulation
Feed Input.parse_input_event(...), call methods on Player, or a dedicated “AI driver” node that mimics _physics_process input?>>
-  

### Should have
    A. TL should be collision aware so that it is capable of avoiding the mobs.
    <<AI Note: “Collision aware” vs architecture: Should-have A asks for mob avoidance; the architecture (section 4) only describes start → play until collision → end, with no mention of what observations TL receives (positions, velocities, distances, raster, etc.). Without that, “collision aware” is not implementable.>>
    B. A way for an external party to end the game if TL prooves to be too good at the game. It can't go on forever. This could be as simple as a Ctrl-C user input from the observer (me while running the debugger). It should trigger a func_game_over()
    C. A way for an external party to notify TL that it is time to start again. (See 4.A. for the start state where main.gd starts as if new.)
-  

### Nice to have
    A. A way for TL to show its thinking.
-  

---

## 4. Technical design

### Architecture / data flow
(Diagram in words: who calls whom, new nodes, autoloads, resources.)
    A. The game is started using the existing scenes and resources and files. 
    B. An external user clicks the "AI Player" button. The main.gd calls the TL interface and notifies TL that it is ready to begin.
    B. TL passes in a value to simulate the keypad enter key being pressed and the game begins.
    C. TL plays and dodges the mobs for as long as possible until a collision occurs.
    D. show_game_over() notifies TL that the game is over.

-  

### Scene & file changes
| Action | Path | Notes |
|--------|------|--------|
| create | `res://dodge-the-creeps/AI_int_lib/` | Dicrectory where all of the files needed for the TL interface will be created/reside |
| modify | `res://dodge-the-creeps/main.gd` | Add the TL interface and communication code. |
| modify | `res://dodge-the-creeps/player.gd` | Add the TL interface and communication code specifically required for TL to control the player. NOTE: This should not disable the ability for a non-TL player to play the game as well |
| modify | `res://dodge-the-creeps/hud.gd` | Add a button ("AI Player") to trigger TL to play the game. |

### Collision / input / signals (if relevant)
- Layers/masks:  
    Defined in mob.gd and player.gd
- New signals:  
    TL's enter, up, down, left, and right keys
- Groups:  

### Dependencies
- Assets:  TinyLLama ({projectHome}/dodge-the-creeps/models/tinyllama-Q4_K_M.gguf) Quantized 4 bit, grouped with medium precision
           Visual and audio files ({projectHome}/dodge-the-creeps/art)
           <<Question: tell me more about "Prompt contract: System + user message shape; how game state is serialized to text (or if you avoid text and use structured logits — unlikely for TL)." I don't think we want to prompt TL every frame with text. Can we give a base set of instruction in text and then provide a way to represent what it's environment is programattically to minimize the number of tokens required for it to choose it's next moove?>>
- Plugins:  
- External APIs:  

---

## 5. Implementation plan (ordered)

1.  Define and implement the TL interface
2.  Define and implement the TL signal path for understanind objects in the game
3.  Define and implement the TL instruction set for avoiding collisions
4.  Define and implement the TL control messaging protocols

---

## 6. Acceptance criteria

(Checklist — agent treats unchecked items as incomplete.)

- [ ]  Interface between Godot and TL is created
- [ ]  Collisiion detection logic written so TL is awayre of the objects in Godot it is avoiding.
- [ ]  TL play parameters defined to keep it focused on solving the problem present.
- [ ]  Key bindings or other mechanism for TL to interact with Godot are defined.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| TL performance. Will it be able to keep up with the godot engine? Will it be so effective that it isn't possible for it to lose?
    <<Question: Threading / frame budget
"**AI Comment**you still need a policy: blocking LLM call per frame, background thread + queued action, max tokens, timeout, fallback action."
Help me understand the pros and cons of the options. I expect we are going to need to tune them. I think we probably want TL to run in a background thread, the the call per frame (or alternately frames per call), max tokens, timeouts, I don't know. We should start conservitively and then measure the performance to find the right values. For this phase the fallback action should be no action (stay stationary)>> | We will need to tuen LLM calls per frame, max tokens, and timeouts to ensure that the LLM can play competitavely however, not be ununable to lose |
|<<Question: What are some other risks I should be considering? >>

---

## 8. Testing / verification

**Manual steps:**  
    A. Run in debugger so a user can watch TL play
-  

**Automated (if any):**  
    A. Automated tests to exersize every code path should be written and run as part of development.

---

## 9. Open questions
    A. 

-  

---

## 10. Changelog (this phase)

| Date | Change |
|------|--------|
| 5/2/26 | Initial Plan doc written |
