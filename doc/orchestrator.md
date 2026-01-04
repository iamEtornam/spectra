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

