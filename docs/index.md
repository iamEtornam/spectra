# Spectra

**A Multi-LLM Spec-Driven Development System written in Dart.**

Spectra is an orchestration layer that makes LLMs reliable for real software engineering. It implements a spec-driven workflow that moves away from "chatting with code" towards "executing specifications".

## Key Features

- **Context Engineering**: Strict line limits and structured state tracking to prevent LLM context degradation.
- **Spec-Driven**: Everything starts with a specification and a plan, ensuring architectural consistency.
- **Multi-Agent Orchestrator**: Launch a team of agents (Mayor, Workers, Witness) to implement tasks in parallel.
- **Multi-LLM Agnostic**: Seamlessly switch between Gemini, Claude, OpenAI, Grok, and DeepSeek.
- **Clean Architecture**: Encourages feature-first, clean architecture patterns.

## Why Spectra?

Most AI tools treat code as a single-shot generation problem. They lack "living memory" of your project state and fail when projects grow beyond a few files. Spectra maintains a "Living Memory" in the `.spectra/` directory, respecting your architecture and conventions.

---

[Next: Getting Started →](/getting-started)

