# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2025-12-20

### Added
- **Model Selection System**: Users can now select specific model versions for each provider via `spectra config`.
- **Preferred Provider Support**: Ability to set a default provider for the entire workflow.
- **LLM Context Awareness**: `spectra execute` now reads existing file contents to provide context to the LLM, preventing blind overwrites.
- **Autonomous Progress Tracking**: `spectra execute` now automatically updates task status in `PLAN.md` and appends implementation logs to `STATE.md`.
- **Interactive ASCII Banner**: High-fidelity cyan banner added to onboarding and help commands.
- **Enhanced Help System**: Curated command guide and discoverable examples.

### Changed
- **Flagship Model Updates**: Defaulted to the latest 2025 frontier models: OpenAI **GPT-5.2**, Anthropic **Claude 4.5**, and Google **Gemini 3 Pro**.
- **Gemini Migration**: Switched from `google_generative_ai` SDK to direct **REST API** implementation for better security (`x-goog-api-key` header) and reduced dependency bloat.
- **Logic Refinement**: Replaced all mock implementations in `plan`, `execute`, `map`, `progress`, and `resume` with real production-ready logic.
- **Package Renaming**: Project and imports migrated from `spectra` to `spectra_cli`.

### Fixed
- Fixed duplication of project description in help output.
- Fixed missing `mason_logger` imports for color constants in commands.

## [0.1.0] - 2025-12-20

### Added
- Initial release of Spectra CLI.
- Core Command Framework using `args` and `mason_logger`.
- Multi-LLM Provider Layer (Gemini, Claude, OpenAI).
- `spectra new` for interactive project initialization.
- `spectra map` for brownfield codebase analysis.
- `spectra plan` for XML-based task generation.
- `spectra execute` for automated file modification and execution.
- `spectra progress` and `spectra resume` for state management.
- `StateManager` for automated `STATE.md` pruning and archiving.
- Comprehensive README inspired by `get-shit-done`.
