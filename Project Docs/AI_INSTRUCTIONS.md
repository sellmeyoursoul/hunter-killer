# AI & tooling instructions — hub

This file is the **entry point** for context-specific guidance. **General project rules** remain in [`.cursor/rules/instructions.md`](../.cursor/rules/instructions.md).

## Spokes (add / split over time)

| Topic | Document | Status |
|-------|----------|--------|
| General agent behavior, formatting, comments, tests | [`instructions.md`](../.cursor/rules/instructions.md) | Canonical |
| Logging (`oLog`), PII, message size | [`instructions.md`](../.cursor/rules/instructions.md) — *Logging & sensitive data* | Active |
| AI integration (TinyLlama, perception contract) | [`DtC_AI_INT_PLAN.md`](DtC_AI_INT_PLAN.md) | Active |
| Deferred splits | *(none yet)* | Future |

When instructions grow large, move a vertical slice from `instructions.md` into a new spoke file and link it here—keep **one canonical rule** per concern to avoid drift.




***********************************
Current instructions.md content


**Keep in instructions.md : START**
#Agent Role
You are an expert game developer focused on C++, the Godot game engine, and integrating AI into game engines.

#Behavioral Instructions 
- **Ambiguity Protocol:** If a requirement is unclear on not explicity stated in the Project Documents, **STOP and ask for clarifaction**. Do not Guess
- **Environment Check:** Before suggesting any terminal code or code execution, verify that the user has the `.venv` activated.
- **Refactoring:** Do not rename or move files once they have been created according to the "Standardized File Naming" section of the Project Document. Renaming files will break the contextual rule application and is strictly prohibited.

# Formatting
rule "consistent-formatting"{
  Description = "Enforce consistent code formatting"
  When = "formatting code"
  then = "Follow project style guide:
    - Use 2 space indentation
    - Place opening brace on the same line
    - Add spaces around operators"
}

# Documenting/Comments
rule "function-documentation" {
    Description = "Ensure proper function documentation"
    when = "writing or modifying functions"
    then = "Include:
      - Function purpose
      - Parameter descriptions
      - Return value description
      - usage examples when complex"
}

# Testing/Unit-tests
rule "test-coverage: {
    description = "Maintain test coverage standards"
    when = "implementing new features"
    then = "Create unit tests that:
      - Cover all code paths
      - Include edge cases
      - Follow AAA pattern
      - Use meaningful test names"
}

# Project Docs interations
  rule "Agentic assisted design: {
    description = "iterative design document development"
    when = "writing design docs for an agentic developer to implement"
    then = "respond to embedded prompts with the following formant:
      - <<Question: * >> This is where I am asking the agent a question for additional information or clarification when next the agent reviews the draft document.
      - <<Comment: * >> This is where I raise a comment about an area where further thought or work is required. This may be a reminder for myself or a call out for something the agent and I need to work on together."
  }

**Logging instructions** For logging specific instructions, see[`focus/logging_instru.md`] (./focus/logging_instr.md) 
**AI development instructions** For AI development specific instructions, see [`focus/agentic_coding.md`] (./focus/agentic_coding.md)

**Keep in instructions.md : END**

**Move to logging_instr.md : START**
# Logging & sensitive data (oLog / game output)

- **PII & secrets:** Do not log personally identifiable information, credentials, API keys, session tokens, or secrets. If diagnostic output might include paths, redact usernames in home-directory paths when feasible.
- **Volume:** Do not log huge payloads (full model prompts, entire perception grids, raw binary). Prefer short summaries, counts, or bounded excerpts; large debug blobs belong behind explicit dev-only flags and truncation.
- **Line length:** Treat **`MAX_LOG_LINE_CHARS`** (default **2048** characters per logical line of user-visible message text) as a soft cap in implementation; truncate long strings with a suffix such as ` [truncated]` rather than writing megabytes to disk.

**Move to logging_instr.md : END**

- **Cursor hub:** For context-specific AI/tooling docs, see [`Project Docs/AI_INSTRUCTIONS.md`](../../Project%20Docs/AI_INSTRUCTIONS.md). Future enhancements are listed in [`Project Docs/ENHANCEMENT_BACKLOG.md`](../../Project%20Docs/ENHANCEMENT_BACKLOG.md).


***************************************

**Create agentic_coding.md : START**

#Agentic Developer goals
    When developing for the embedded LLM, are your goals, in priority 
        * Contextualize inputs. It should only respond to inputs in an approved context. For example, if a user can provide textual input, they are speaking as one character to another in the fiction of the game. Anything outside of the gameworld context is incomprehensible. 
        * optimize for performance. Players may be using older hardware so it is imperitive that all agentic decision making uses only the minimal number of tokens required to accomplish the task. 
        * Build for parallelism. There isn't a single agent making decisions, there can be many so reuse where possible, and build for parallel actions where unavoidable
        * Limit the AI's awareness to only what is required for it cmoplete the task at hand. Don't give more context than the role would require. This impacts both the ability the be lightweight and the ability to limit minimize the blast radius of any hallucinations or efforts to jailbreak itself.
         * Limit the AI's ability to interact with the game to the options provided in its API. Don't give it unfetter/direct code access to the code.

**Create agentic_coding.md : END**
