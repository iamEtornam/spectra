# Spectra

**A Multi-LLM Spec-Driven Development System for Dart & Flutter.**

![Spectra UI](https://raw.githubusercontent.com/glittercowboy/get-shit-done/main/assets/terminal.svg)

AI-driven development often leads to technical debt, inconsistent patterns, and "AI hallucinations" that break your build.

**Spectra fixes that.** It's the multi-agent context engineering layer that makes LLMs (Gemini, Claude, OpenAI, Grok, DeepSeek) reliable for real software engineering. Describe your idea, map your existing codebase, and let Spectra orchestrate the execution with precision.

THIS is how you build systems that actually last.

_Warning: Not for developers who enjoy manual boilerplate and inconsistent code quality._

---

## Installation

```bash
# Clone the repository
git clone https://github.com/your-username/spectra.git
cd spectra

# Install dependencies
dart pub get

# (Optional) Activate globally
dart pub global activate --source path .
```

Verify: `spectra --help`

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

### 4. Plan & Execute
```bash
spectra plan "Auth Implementation"
spectra execute
```
The Planner breaks your roadmap into 2–5 atomic tasks in **XML format**. The Execution Engine then parses these tasks, applies file changes, runs verification, and commits to Git.

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

| Command    | Description                                             |
| ---------- | ------------------------------------------------------- |
| `new`      | Interactive onboarding to start a new project           |
| `map`      | Analyze existing repository architecture (Brownfield)   |
| `plan`     | Break a roadmap phase into atomic XML tasks            |
| `execute`  | Parse plans, apply changes, and commit to Git           |
| `progress` | Visual dashboard of completed vs. upcoming phases       |
| `resume`   | Detect interrupted states and pick up where you left off|
| `config`   | Set up API keys for Gemini, Claude, OpenAI, Grok, and DeepSeek |

---

## Who This Is For

Creative engineers who want to build complex systems without being bogged down by manual implementation details.

If you want to define the *what* and have a system you trust handle the *how*—while maintaining full architectural control—Spectra is for you.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

**Spectra: Precision-guided software engineering.**
