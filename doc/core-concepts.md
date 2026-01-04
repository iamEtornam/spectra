# Core Concepts

Spectra is built on several fundamental principles that ensure high-quality, consistent code generation.

## The Living Memory (`.spectra/`)

The heart of Spectra is the `.spectra/` directory. It contains the "Living Memory" of your project:

| File | Purpose |
| :--- | :--- |
| `PROJECT.md` | Core vision, tech stack, and constraints (Immutable). |
| `ROADMAP.md` | High-level phases and milestones. |
| `STATE.md` | Current technical decisions & blockers (Auto-pruned). |
| `PLAN.md` | Atomic tasks in XML format generated from roadmap. |
| `SUMMARY.md` | Results of the last execution. |
| `ISSUES.md` | Deferred enhancements and technical debt. |

## Context Engineering

LLMs perform best when context is focused. Spectra automatically prunes `STATE.md` when it grows too large, archiving older context into `history/` while keeping recent, relevant decisions at the forefront.

## XML Task Prompting

Spectra uses structured XML task blocks in `PLAN.md`. This format is optimized for LLM precision, specifically for models like Claude and Gemini, allowing for clear separation of objectives, file lists, and verification steps.

```xml
<task id="task_001" type="create">
  <n>Implement User Auth</n>
  <files>
    <file>lib/features/auth/domain/entities/user.dart</file>
  </files>
  <objective>Create the User entity with id and email.</objective>
  <verification>Check if the entity is correctly defined.</verification>
  <acceptance>User entity exists in the domain layer.</acceptance>
</task>
```

## Spec-Driven Development

Instead of jumping straight to coding, Spectra forces a planning phase:
1. **Map/New**: Establish the base context.
2. **Plan**: Generate specific XML tasks for a feature.
3. **Execute/Start**: Run the agents to implement the plan.

