# Context Engineering

LLMs perform best when their context is small, focused, and relevant. Spectra treats context as a managed resource rather than an ever-growing transcript, which keeps generation quality consistent as projects scale.

## Why Focused Context Matters

As a project grows, dumping the entire history of decisions and source files into every prompt degrades output: models lose track of what is current, latch onto stale details, and burn tokens on noise. Spectra's answer is to keep each prompt anchored to a small, curated slice of the "Living Memory".

## STATE.md Auto-Pruning

`STATE.md` records current technical decisions and blockers, so it naturally accumulates entries over time. The `StateManager` keeps it bounded:

- When `STATE.md` exceeds **200 lines**, pruning is triggered automatically.
- The **full file** is first archived to `.spectra/history/state-<timestamp>.md`, so nothing is ever lost.
- Only the **last 50 lines** are kept in `STATE.md`, under a `# STATE (Pruned)` header.

This means the working state file always stays lean, while the complete decision history remains browsable in `.spectra/history/` if you (or an agent) ever need to dig into older context.

## Line-Limit Philosophy

The 200-line threshold is deliberate: it is large enough to hold the decisions that matter for the current phase, and small enough to fit comfortably in a prompt alongside the task definition and file context. Recent decisions are almost always the relevant ones — older entries are archived, not carried forward.

## Per-Task File Context

Tasks in `PLAN.md` declare exactly which files they touch:

```xml
<task id="task_001" type="create">
  <files>
    <file>lib/features/auth/domain/entities/user.dart</file>
  </files>
  ...
</task>
```

When `spectra execute` (or a Worker agent) runs a task, it builds the prompt context from **only those declared files** — reading each one's current content, or noting that it does not exist yet. The rest of the codebase stays out of the prompt. This keeps every LLM call focused on the objective at hand and prevents context bleed between unrelated tasks.

## Summary

- `STATE.md` is auto-pruned at 200 lines; history is archived to `.spectra/history/`.
- Only the most recent 50 lines of state travel forward.
- Each task pulls only its declared file context — nothing more.
