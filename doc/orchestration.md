# Orchestration

Spectra ships two orchestration paths. Both are launched with `spectra start`; which one runs depends on whether a `WORKFLOW.md` file is present (and on the `--legacy` flag). This page is a high-level map — see the [Multi-Agent Orchestrator](/orchestrator) page for full detail on either path.

## Path 1: Legacy PLAN.md Orchestrator

The original multi-agent "convoy" model, driven entirely by `.spectra/PLAN.md`:

- **Mayor** — watches for pending tasks in `PLAN.md` and assigns them to available Workers.
- **Workers** — pull the task's file context, call the coding LLM, apply changes, and mark tasks completed or failed. Spawn count is controlled with `--workers/-w` (default: 2).
- **Witness** — monitors agent health, detects stuck workers, and releases their tasks back to the pool.

This path still runs when no `WORKFLOW.md` exists, or when you force it with `spectra start --legacy`.

## Path 2: Symphony-Aligned Scheduler (v0.2)

The tracker-driven service model, configured by a repo-owned `WORKFLOW.md` file:

```
WORKFLOW.md → WorkflowLoader → IssueTrackerClient → Scheduler
                                                       │
                              WorkspaceManager ← ──────┤
                                                       │
                              AgentRunner ─ → proof-of-work
```

- **`WorkflowLoader`** parses `WORKFLOW.md` (YAML front matter + Markdown prompt body) into a typed `WorkflowConfig`. `WorkflowWatcher` hot-reloads it on change.
- **`IssueTrackerClient`** supplies work items: `local_plan` (the default, adapting `.spectra/PLAN.md` tasks) or `linear` (Linear GraphQL).
- **`Scheduler`** is the single authority: it polls the tracker, claims issues, dispatches runs, retries failures, reconciles state, and detects stalls. Continuations stop when `agent.max_turns` is reached.
- **`WorkspaceManager`** creates one git worktree per issue and runs lifecycle hooks around it.
- **`AgentRunner`** executes the work — `LlmAgentRunner` (the only implemented runner) writes generated files into the per-issue worktree.
- **Proof of work** — every completed run writes a `proof.md` under `.spectra/runs/<run_id>/` recording changed files, hook outcomes, retries, and a recommendation.

### Run-Attempt Lifecycle

Each issue moves through a run attempt owned by the Scheduler:

1. **Claim** — the Scheduler claims an eligible issue from the tracker.
2. **Workspace** — a dedicated git worktree is created (with `after_create`/`before_run` hooks).
3. **Run** — the AgentRunner executes turns until the work completes or `max_turns` is hit.
4. **Finalize** — `after_run`/`before_remove` hooks fire, proof-of-work is written, and the issue is marked complete — or queued for retry on failure.

Live status for both paths is available via `spectra progress` (add `--runs` for the scheduler snapshot) and `spectra dashboard`.

For configuration details, tracker setup, runtime snapshot endpoints, and error recovery, see [Multi-Agent Orchestrator](/orchestrator).
