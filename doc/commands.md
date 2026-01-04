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

The **Multi-Agent Orchestrator**. Launches a team of agents to process `PLAN.md` in parallel.

**Options**:
- `--workers, -w`: Number of worker agents to spawn (default: `2`).

## `progress`
**Usage**: `spectra progress`

Provides a visual dashboard of your project's status, showing completed vs. upcoming phases based on your roadmap and project state.

## `resume`
**Usage**: `spectra resume`

Detects if an execution was interrupted and attempts to pick up exactly where it left off by checking the current state in `PLAN.md`.

## `config`
**Usage**: `spectra config`

Configure your global settings, including API keys and preferred models for each provider.

