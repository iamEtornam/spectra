# Multi-Agent Orchestrator

The Orchestrator is a sophisticated layer in Spectra that leverages multiple agents to accelerate project implementation. It is inspired by multi-agent systems like *Gastown*.

## How it Works

When you run `spectra start`, Spectra initializes an `OrchestratorService` that manages a group of specialized agents. These agents communicate through the "Living Memory" (`.spectra/`) and a shared task queue.

## Agent Roles

### The Mayor
The **Mayor** is the coordinator of the town.
- **Job**: Watches for pending tasks in `PLAN.md`.
- **Action**: Assigns tasks to available Workers.

### The Worker
The **Worker** is the primary executor (equivalent to *Polecats* in Gastown).
- **Job**: Takes an assigned task, pulls the necessary file context, calls the LLM, and applies the changes.
- **Action**: Marks tasks as completed or failed upon finishing.

### The Witness
The **Witness** is the monitor of health.
- **Job**: Periodically checks the activity of all agents.
- **Action**: Detects stuck workers (no activity for X minutes) and marks them for reset or intervention.

## Parallelism and Efficiency

By default, `spectra start` spawns **2 workers**, allowing two coding tasks to be implemented simultaneously. This significantly reduces the time required for large features that touch many independent files.

## Propulsion Principle

Agents follow a "Propulsion Principle": **If there is work on your hook, run it.** They don't wait for human intervention unless they hit a blocker they cannot resolve.

## Error Recovery

The orchestrator includes robust error recovery mechanisms:

### Automatic Stuck Detection
- Agents inactive for more than 5 minutes while in "working" status are automatically detected as stuck.
- Stuck agents have their tasks released back to the pool for reassignment.
- The agent is reset to `idle` status and can resume work.

### Consecutive Failure Tracking
- Each agent tracks consecutive failures.
- After 3 consecutive failures, an agent is marked as `failed`.
- Failed agents are excluded from task assignment until manually restarted.

### Timeout Handling
- All LLM API calls have configurable timeouts (default: 60 seconds).
- Timed out requests are automatically retried with exponential backoff.
- Rate limiting from providers is detected and handled gracefully.

## LLM Response Caching

Spectra includes an LRU cache for LLM responses to reduce API costs:

- **In-Memory Cache**: Fast lookups with configurable max entries (default: 100).
- **Persistent Storage**: Cache survives restarts via `~/.spectra/cache.json`.
- **TTL-Based Expiration**: Entries expire after 24 hours by default.
- **Automatic Cache Keys**: Based on prompt, model, and context hash.

To disable caching, pass `enableCaching: false` when creating the `LLMService`.

## Human Monitoring (The Overseer)

You can monitor the active agents in real-time while the orchestrator is running.

### CLI Dashboard
Open a separate terminal and run:
```bash
spectra progress
```

This displays a **Live Agent Status** dashboard in your terminal showing each agent's current state (IDLE, WORKING, STUCK, etc.) and their assigned tasks.

### Web Dashboard
For a visual, browser-based experience:
```bash
spectra dashboard
```

This launches a real-time web UI at `http://localhost:3000` featuring:
- **Agent Cards**: Live status of all agents with role indicators.
- **Progress Tracking**: Visual progress bar for project completion.
- **Activity Timeline**: Recent agent activity log.
- **Auto-Refresh**: Updates every 2 seconds automatically.

You can specify a custom port with `--port` or `-p`:
```bash
spectra dashboard --port 8080
```

