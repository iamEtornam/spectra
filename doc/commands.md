# CLI Command Reference

Detailed guide for all Spectra CLI commands.

## `new`
**Usage**: `spectra new`

Initializes a greenfield project. It runs an interactive onboarding session where you define the project's soul, tech stack, and constraints.

## `map`
**Usage**: `spectra map`

Analyzes an existing codebase (Brownfield). It scans directories to identify patterns, tech stack, and architecture, saving this context to `.spectra/PROJECT.md`.

## `plan`
**Usage**: `spectra plan "description"`

Generates an implementation plan based on your current project state and the provided description. It updates `PLAN.md` with XML-formatted tasks.

## `execute`
**Usage**: `spectra execute`

The sequential execution engine. It reads `PLAN.md`, executes tasks one by one using a single agent, applies changes, and commits to Git.

## `start`
**Usage**: `spectra start [options]`

The **Multi-Agent Orchestrator**. If a `WORKFLOW.md` file is present, it runs the Symphony-aligned scheduler; otherwise it launches the legacy team of agents to process `PLAN.md` in parallel.

**Options**:
- `--workers, -w`: Number of worker agents to spawn in legacy mode (default: `2`).
- `--workflow`: Path to the `WORKFLOW.md` file (defaults to `./WORKFLOW.md`).
- `--manual, -m`: Manual mode — show task assignments without generating code.
- `--legacy`: Force the legacy convoy/`PLAN.md` orchestrator even when `WORKFLOW.md` is present.

Note: `start` has no `--port` option — that belongs to `dashboard`.

## `dashboard`
**Usage**: `spectra dashboard [options]`

Launches a web-based monitoring dashboard at `http://localhost:3000`. This provides a real-time visual interface for monitoring agent activity, project progress, and system health.

**Options**:
- `--port, -p`: Port to run the dashboard on (default: `3000`).

**Features**:
- Live agent status with role indicators (Mayor, Worker, Witness).
- Task assignment visibility.
- Project progress bar.
- Auto-refresh every 2 seconds.

## `progress`
**Usage**: `spectra progress [options]`

Provides a CLI dashboard of your project's status, showing completed vs. upcoming phases based on your roadmap and project state. 

**Options**:
- `--runs`: Print the scheduler's runtime snapshot (Symphony mode) in the terminal.

**Live Monitoring**: If the Multi-Agent Orchestrator (`spectra start`) is currently running, this command also displays a real-time status dashboard of all active agents and the tasks they are currently processing.

## `resume`
**Usage**: `spectra resume`

Detects if an execution was interrupted by checking task statuses in `PLAN.md`. It counts tasks already marked `status="completed"` versus those remaining, reports "X completed, Y remaining", and continues execution with the first uncompleted task.

## `config`
**Usage**: `spectra config`

Configure your global settings, including API keys and preferred models for each provider.

