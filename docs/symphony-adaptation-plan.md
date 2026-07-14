# Symphony Adaptation Plan

This plan adapts OpenAI Symphony's work-orchestration approach to Spectra while
preserving Dart as the implementation language and keeping Spectra's existing
CLI, `.spectra` living memory, multi-provider LLM support, and Jaspr dashboard.

## Goal

Evolve Spectra from a spec-driven task executor into a long-running, policy-led
work orchestration service.

Symphony's core idea is not simply "more agents." It is a repeatable service
that:

- Reads repo-owned workflow policy.
- Polls an issue tracker for eligible work.
- Creates isolated per-issue workspaces.
- Runs coding agents inside those workspaces.
- Reconciles tracker state before dispatching more work.
- Retries transient failures with backoff.
- Exposes enough observability for operators to trust and debug autonomous runs.

## Keep From Spectra

- Dart CLI entrypoint in `bin/spectra.dart`.
- Existing command flow: `new`, `map`, `plan`, `execute`, `start`, `progress`,
  `resume`, and `dashboard`.
- `.spectra` living memory files: `PROJECT.md`, `ROADMAP.md`, `STATE.md`,
  `PLAN.md`, `SUMMARY.md`, and `ISSUES.md`.
- Planning/coding provider separation through `LLMService`.
- Current local dashboard built with Jaspr and Shelf.
- Manual, interactive, and automatic execution modes.

## Add From Symphony

- A repo-owned `WORKFLOW.md` contract with YAML front matter and prompt body.
- A typed workflow config layer with defaults, validation, and environment
  variable resolution.
- A tracker integration layer, starting with Linear-compatible issue polling.
- A workspace manager for sanitized per-issue workspaces and lifecycle hooks.
- A runner abstraction that can use the current Spectra LLM execution path first
  and a Codex app-server protocol later.
- A single-authority orchestrator state machine for claimed, running, retrying,
  released, and completed work.
- Structured runtime events, metrics, and proof-of-work artifacts.
- Run-centric dashboard and CLI status surfaces.

## Target Architecture

```text
WORKFLOW.md
  -> WorkflowLoader
  -> WorkflowConfig
  -> IssueTrackerClient
  -> Orchestrator/Scheduler
  -> WorkspaceManager
  -> AgentRunner
  -> Structured events, logs, dashboard, and proof-of-work
```

Recommended module layout:

```text
lib/features/
  workflow/
    workflow_definition.dart
    workflow_config.dart
    workflow_loader.dart
    workflow_failure.dart
  tracker/
    issue.dart
    issue_tracker_client.dart
    linear_tracker_client.dart
  workspaces/
    workspace.dart
    workspace_manager.dart
    workspace_hooks.dart
  runner/
    agent_runner.dart
    llm_agent_runner.dart
    codex_app_server_runner.dart   # (planned, not yet implemented)
  orchestration/
    run_attempt.dart
    retry_entry.dart
    orchestrator_state.dart        # implemented as scheduler.dart + running_entry.dart + codex_totals.dart
    orchestration_event.dart
  observability/
    runtime_snapshot.dart
    proof_of_work.dart
```

## Workflow Contract

Default discovery should look for `WORKFLOW.md` in the current working
directory. Spectra may later support an explicit `--workflow` path.

The file has optional YAML front matter and a Markdown prompt body:

```markdown
---
tracker:
  kind: linear
  api_key: $LINEAR_API_KEY
  project_slug: spectra
  active_states:
    - Todo
    - In Progress
polling:
  interval_ms: 30000
workspace:
  root: .spectra/workspaces
agent:
  max_concurrent_agents: 3
  max_turns: 20
---

You are working on {{ issue.identifier }}.

Implement the issue, run verification, and produce proof of work.
```

Initial front matter keys:

- `tracker`
- `polling`
- `workspace`
- `hooks`
- `agent`
- `codex`
- `server`

Unknown keys should be ignored for forward compatibility.

## Runtime State Model

The scheduler owns all state mutations. Workers and runners emit events.

Internal issue orchestration states:

```text
Unclaimed -> Claimed -> Running -> RetryQueued -> Running
                       -> Released
```

Run attempt phases:

```text
PreparingWorkspace
BuildingPrompt
LaunchingAgentProcess
InitializingSession
StreamingTurn
Finishing
Succeeded
Failed
TimedOut
Stalled
CanceledByReconciliation
```

Success does not automatically mean the issue is done forever. After a normal
worker exit, the scheduler should re-check tracker state. If the issue is still
active, it may continue the same work item up to the configured turn limit.

## Workspace Safety

The workspace manager must enforce these invariants:

- Workspace keys are sanitized to `[A-Za-z0-9._-]`.
- The final workspace path must remain inside the configured workspace root.
- Agent subprocesses must run with `cwd` equal to the per-issue workspace path.
- Successful runs should preserve workspaces for inspection.
- Terminal issue states may trigger cleanup through explicit policy.

Supported lifecycle hooks:

- `after_create`
- `before_run`
- `after_run`
- `before_remove`

`after_create` and `before_run` failures should fail the current attempt.
`after_run` and `before_remove` failures should be logged and ignored.

## Observability

Replace `AGENTS.json` as the primary contract with a structured runtime
snapshot. It should include:

- Running sessions.
- Retry queue.
- Claimed issue IDs.
- Latest runtime events.
- Workspace paths.
- Token and runtime totals.
- Latest rate-limit information when available.
- Current workflow validation errors.
- Proof-of-work links for completed or reviewable runs.

The dashboard should be run-first, not agent-first:

```text
System health
  -> Work queue
  -> Selected run
  -> Attempt timeline
  -> Agent events
  -> Evidence and approval history
```

## CLI Evolution

Preserve existing commands and add Symphony-style capabilities gradually.

Near-term additions:

```bash
spectra start --workflow WORKFLOW.md --port 3000
spectra progress --runs
spectra resume run_abc
```

Future additions:

```bash
spectra run issue SPECTRA-123
spectra approve run_abc --gate files
spectra retry run_abc --task task_004
spectra verify run_abc
spectra review run_abc
```

## Implementation Phases

### Phase 0: Foundation

- Add workflow definition, typed config, and workflow failure models.
- Add `WorkflowLoader` for front matter parsing and prompt extraction.
- Add tests for missing files, invalid front matter, defaults, and environment
  variable resolution.

### Phase 1: Tracker Mode

- Add normalized `Issue` model.
- Add `IssueTrackerClient` interface.
- Implement Linear-compatible candidate fetch and state refresh.
- Add fake tracker tests for active, terminal, blocked, and priority sorting.

### Phase 2: Workspace Isolation

- Add `WorkspaceManager`.
- Sanitize issue identifiers into workspace keys.
- Normalize workspace roots to absolute paths.
- Add hook execution with timeout.
- Add path traversal, hook failure, and cleanup tests.

### Phase 3: Runner Abstraction

- Introduce `AgentRunner`.
- Wrap current LLM worker behavior in `LlmAgentRunner`.
- Add prompt rendering from `WORKFLOW.md`.
- Add normalized runner events and error categories.
- Later add `CodexAppServerRunner` as a separate adapter.

### Phase 4: Scheduler Refactor

- Refactor `OrchestratorService` into a single-authority scheduler.
- Track `claimed`, `running`, `retryAttempts`, `completed`, and aggregate
  metrics.
- Reconcile running issues before each dispatch.
- Add exponential retry and continuation retry behavior.
- Stop runs when tracker state becomes terminal or non-active.

### Phase 5: Observability and Control Plane

- Add runtime snapshot API under `/api/v1/state`.
- Add run, issue, session, and event endpoints.
- Add pause, resume, cancel, retry, approve, and reject control actions.
- Update `progress` and dashboard to use the same snapshot model.

### Phase 6: Product Hardening

- Add proof-of-work artifacts: diff summary, changed files, tests, checks,
  commits, approvals, retries, risks, and final recommendation.
- Add workflow docs and examples.
- Add migration guide from `PLAN.md`-only orchestration.
- Add real integration profile tests for tracker, workspace hooks, and runner.

## UX and Trust Principles

The product should feel like supervised autonomy, not hidden automation.

- Make work items and runs primary; agents are secondary implementation details.
- Show why each item was selected and what will happen next.
- Treat retries as inspectable incidents with cause and recovery strategy.
- Require approvals for risky transitions: dependency changes, broad rewrites,
  external publishing, destructive git actions, repeated failures, and low
  confidence output.
- Preserve user agency with pause, resume, cancel, retry, replan, approve,
  reject, and manual handoff.
- Produce proof of work for every completed run.

## Documentation Updates

As this is built, keep these files current:

- `README.md`
- `doc/orchestrator.md`
- `doc/core-concepts.md`
- `doc/commands.md`
- `doc/architecture-llm-separation.md`
- `docs.json`
- `docs/symphony-adaptation-plan.md`

If an OpenAPI or Swagger document is introduced for the dashboard API, update it
in the same change that modifies the API.
