# Spectra

**A Multi-LLM Spec-Driven Development System written in Dart**

![Spectra UI](assets/file.png)

AI-driven development often leads to technical debt, inconsistent patterns, and "AI hallucinations" that break your build.

**Spectra fixes that.** It's the multi-agent context engineering layer that makes LLMs (Gemini, Claude, OpenAI, Grok, DeepSeek) reliable for real software engineering. Describe your idea, map your existing codebase, and let Spectra orchestrate the execution with precision.

THIS is how you build systems that actually last.

_Warning: Not for developers who enjoy manual boilerplate and inconsistent code quality._

---

## Installation

```
dart pub global activate spectra_cli
```

Use it: `spectra`

---

## Why I Built This

I'm an engineer who loves building, not babysitting LLMs. 

Most AI tools treat code like a single-shot generation problem. They lack "living memory" of your project state and fail when projects grow beyond a few files. I didn't want a "chat with your code" tool; I wanted a **Spec-Driven Execution Engine** that respects my architecture, follows my conventions, and doesn't forget decisions made three days ago.

So I built Spectra. It's designed for small-to-medium projects (1–50 files) where precision matters more than volume. 

- **Context Engineering**: Strict line limits and structured state tracking.
- **XML Prompting**: Optimized for LLM precision (especially Claude & Gemini).
- **Multi-LLM Agnostic**: Switch between Gemini-3.0, Claude-4.5, GPT-5, Grok-4.1, and DeepSeek-V3.2 with ease.
- **Git Native**: Every task is an atomic commit with clear rationale.

Spectra allows me to focus on high-level architecture while it handles the implementation and verification. It's the system I trust to get work done.

---

## How It Works

### 1. Configuration (First-time setup)
```bash
spectra config
```
Spectra will prompt you for your API keys for Google Gemini, OpenAI, Anthropic Claude, xAI Grok, and DeepSeek. These are stored locally in `~/.spectra/config.yaml`.

### 2. New Projects (Greenfield)
```bash
spectra new
```
Interactive onboarding. Spectra asks about your project vision, tech stack, and constraints. It initializes the `.spectra/` directory with your "Living Memory".

### 3. Existing Projects (Brownfield)
```bash
spectra map
```
Scans your existing repository to extract architecture, naming conventions, and tech stack into the `.spectra/` context. Spectra learns your style before it writes a single line of code.

### 4. Plan & Orchestrate
```bash
spectra plan "Auth Implementation"
spectra start --workers 3
```
The Planner breaks your roadmap into 2–5 atomic tasks. While `spectra execute` runs tasks sequentially, **`spectra start`** launches a Multi-Agent Orchestrator inspired by *Gastown*.

- **Mayor Agent**: Coordinates task assignment.
- **Worker Agents**: Parallel executors that implement tasks.
- **Witness Agent**: Monitors health and detects stuck workers.

**Monitor in real-time**: While `spectra start` is running, you can use `spectra progress` in another terminal to see the live status of all active agents and their assigned tasks. For a visual experience, run `spectra dashboard` to launch a web-based monitoring UI.

---

## Why It Works: Context Engineering

Spectra maintains a "Living Memory" in the `.spectra/` directory. Every file has strict line limits to prevent LLM context degradation.

| File          | Purpose                                               |
| ------------- | ----------------------------------------------------- |
| `PROJECT.md`  | Core vision, tech stack, and constraints (Immutable) |
| `ROADMAP.md`  | High-level phases and milestones                      |
| `STATE.md`    | Current technical decisions & blockers (Auto-pruned)  |
| `PLAN.md`     | Atomic tasks in XML format                            |
| `SUMMARY.md`  | Results of the last execution                         |
| `ISSUES.md`   | Deferred enhancements and technical debt              |

When `STATE.md` grows too large, Spectra automatically archives older decisions to `history/`, keeping the most relevant context at the forefront.

---

## Commands

| Command     | Description                                             |
| ----------- | ------------------------------------------------------- |
| `new`       | Interactive onboarding to start a new project           |
| `map`       | Analyze existing repository architecture (Brownfield)   |
| `plan`      | Break a roadmap phase into atomic XML tasks            |
| `execute`   | Parse plans, apply changes, and commit to Git (Sequential) |
| `start`     | Launch the Multi-Agent Orchestrator (Parallel execution) |
| `dashboard` | Launch web UI for real-time agent monitoring            |
| `progress`  | CLI dashboard of completed vs. upcoming phases          |
| `resume`    | Detect interrupted states and pick up where you left off|
| `config`    | Set up API keys for Gemini, Claude, OpenAI, Grok, and DeepSeek |

---

## Who This Is For

Creative engineers who want to build complex systems without being bogged down by manual implementation details.

If you want to define the *what* and have a system you trust handle the *how*—while maintaining full architectural control—Spectra is for you.

---

## Roadmap / TODO

Future enhancements planned for Spectra:

- [ ] **Expand Test Coverage** — Add integration tests for commands and end-to-end workflows
- [ ] **Security Hardening** — Encrypted storage for API keys (instead of plain YAML)
- [ ] **Metrics & Telemetry** — Track agent performance, task completion times, and LLM costs over time
- [ ] **Plugin System** — Allow custom LLM providers and agent types via plugins
- [x] **Web Dashboard** — Real-time browser UI for monitoring agents, built with [Jaspr](https://docs.jaspr.site)
- [ ] **Task Dependencies** — Support for task ordering and prerequisite chains in `PLAN.md`
- [ ] **Rollback Support** — Automatic Git rollback when a task fails verification

Contributions welcome! Feel free to open issues or pull requests on [GitHub](https://github.com/iamEtornam/spectra).

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

**Spectra: Precision-guided software engineering.**
