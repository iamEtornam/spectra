# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.5] - 2026-02-06

### Added
- **Execution Modes**: Three modes for different workflows.
  - `ExecutionMode.automatic`: AI plans and implements code (default).
  - `ExecutionMode.manual`: AI plans, user implements code manually.
  - `ExecutionMode.interactive`: AI generates, user reviews and approves.
  - New `--manual` and `--auto` flags for `execute` and `start` commands.
  - `executionMode` field in `SpectraConfig` for persistent preference.
  - Allows using Spectra purely as a planning tool without code generation.
  - See `doc/execution-modes.md` for comprehensive guide.
- **LLM Usage Type Separation**: Separate provider configuration for planning vs coding tasks.
  - New `LLMUsageType` enum with `planning` and `coding` variants.
  - `planningProvider` and `codingProvider` fields in `SpectraConfig`.
  - `getProviderForUsage(LLMUsageType)` method in `LLMService`.
  - Planning tasks: `plan`, `map`, Mayor/Witness agents (strategic analysis).
  - Coding tasks: `execute`, `start`, Worker agents (code generation).
  - Allows cost optimization (e.g., Claude for planning, Gemini Flash for coding).
  - Backward compatible with existing `preferredProvider` configuration.
  - See `doc/llm-usage-types.md` for comprehensive guide and recommendations.
- **Encrypted Credential Storage**: API keys are now encrypted using machine-specific encryption.
  - New `SecureStorageService` with PBKDF2 key derivation (10,000 iterations).
  - Keys stored in `~/.spectra/.secure/` with filesystem-based protection.
  - Automatic migration from legacy plain-text YAML config.
  - Machine-bound encryption prevents credential theft across systems.
- **Comprehensive Test Suite**: Significantly expanded test coverage to 85%+.
  - Unit tests for `SecureStorageService` and updated `ConfigService`.
  - Integration tests for `config`, `map`, and `plan` commands.
  - End-to-end workflow tests covering complete user journeys:
    - New project (greenfield) setup workflow.
    - Existing project (brownfield) mapping workflow.
    - Task execution and verification workflow.
    - Multi-agent orchestration workflow.
    - Configuration migration workflow.
  - Model tests for `SpectraConfig` with serialization validation.
- **Security Documentation**: New `doc/security.md` with detailed security features:
  - Encryption implementation details.
  - Key derivation process.
  - Migration guide from legacy format.
  - Security best practices and limitations.
  - FAQ for common security questions.
- **Testing Documentation**: New `doc/testing.md` with comprehensive testing guide:
  - Test structure and organization.
  - Running tests and coverage reports.
  - Test categories (unit, integration, e2e).
  - Testing best practices.
  - Security and performance testing.
  - CI/CD integration guidelines.

### Changed
- **ConfigCommand**: Enhanced to configure separate planning and coding providers.
  - New interactive prompts for planning provider selection.
  - New interactive prompts for coding provider selection.
  - Clear descriptions and recommendations for each usage type.
  - Shows selected providers on success.
- **Commands Updated for Usage Types**:
  - `PlanCommand` now uses planning provider (strategic task breakdown).
  - `MapCommand` now uses planning provider (architecture analysis).
  - `ExecuteCommand` now uses coding provider (code generation).
  - `OrchestratorService` uses both: planning for Mayor/Witness, coding for Workers.
- **ConfigService**: Refactored to use encrypted storage instead of plain YAML.
  - All API keys now stored securely in encrypted format.
  - Legacy `config.yaml` automatically migrated on first load.
  - New `clearConfig()` and `hasConfig` methods for better management.
- **SpectraConfig Model**: Enhanced with secure storage support.
  - New `fromMap()` factory for encrypted storage deserialization.
  - New `toMap()` method for encrypted storage serialization.
  - Maintains backward compatibility with YAML format for migration.
- **README**: Updated with security features and completed roadmap items.
  - Added "Security Features" section highlighting encryption.
  - Marked "Expand Test Coverage" and "Security Hardening" as complete.
  - Updated configuration description to mention encrypted storage.

### Dependencies
- Added `path` ^1.9.0 for cross-platform path handling.

### Security
- **Breaking Change**: API keys are no longer stored in plain text.
  - Existing `~/.spectra/config.yaml` will be automatically migrated.
  - Backup your keys before upgrading if you want to preserve plain-text access.
  - After migration, legacy `config.yaml` is deleted for security.

### Fixed
- Eliminated plain-text API key storage vulnerability.
- Improved test isolation with proper setup/teardown in all test files.

## [0.1.4] - 2026-01-08

### Changed
- Updated `jaspr` dependency to ^0.22.1.

### Fixed
- Fixed lint warnings in `CodebaseContextService` (prefer single quotes).

## [0.1.3] - 2026-01-05

### Added
- **Test Suite**: Comprehensive unit tests for agents, models, and utilities.
  - Tests for `AgentState` JSON serialization/deserialization.
  - Tests for `SpectraTask` XML parsing.
  - Tests for `WorkerAgent` task assignment and execution.
  - Tests for `StateManager` pruning logic.
- **LLM Response Caching**: New caching layer to reduce API costs.
  - LRU cache with configurable size and TTL.
  - Persistent file-based caching in `~/.spectra/cache.json`.
  - `CachedLLMProvider` wrapper for transparent caching.
- **Timeout & Retry Handling**: Robust HTTP request handling.
  - Configurable timeouts for all LLM API calls (default: 60s).
  - Automatic retry with exponential backoff.
  - Rate limit detection and handling.
- **Enhanced Error Recovery**: Improved multi-agent resilience.
  - `OrchestratorConfig` for customizable orchestrator behavior.
  - Automatic stuck agent detection and recovery.
  - Consecutive failure tracking with configurable thresholds.
  - Task release and reassignment when workers fail.
  - `restartAgent()` method for manual recovery.
- **API Documentation**: Comprehensive doc comments throughout codebase.
  - All public APIs documented with examples.
  - Agent roles, states, and lifecycle documented.
  - LLM provider interface fully documented.
- **Web Dashboard**: Real-time browser-based agent monitoring UI.
  - New `spectra dashboard` command to launch the web server.
  - Built with [Jaspr](https://docs.jaspr.site/) for component-based server-side rendering.
  - Reusable components: `DashboardPage`, `AgentCard`, `ProgressCard`.
  - Live agent status with role indicators (Mayor 👔, Worker 🔧, Witness 👁️).
  - Project progress tracking with visual progress bar.
  - Auto-refresh every 2 seconds.
  - Modern dark theme with responsive design.
  - Configurable port via `--port` flag.

### Changed
- Replaced `Timer.periodic` with proper async loop in orchestrator to prevent race conditions.
- Workers now properly reset to `idle` status after completing tasks.
- All LLM providers now use `HttpUtils` for consistent timeout/retry behavior.
- `SpectraCommand` now extends `Command<void>` for type safety.
- Added `analysis_options.yaml` with strict linting rules.
- Updated minimum Dart SDK to 3.10.0 for modern language features.

### Dependencies
- Added `jaspr` ^0.22.0 for component-based web dashboard.
- Added `shelf` ^1.4.1 and `shelf_router` ^1.1.4 for HTTP server.
- Added `crypto` ^3.0.3 for cache key hashing.
- Added `mocktail` ^1.0.4 (dev) for testing.

### Fixed
- Fixed orchestrator race condition where agent steps could execute concurrently.
- Fixed worker agents becoming permanently unavailable after first task completion.
- Fixed nullable field promotion issues in `LLMCache`.
- Fixed LRU cache corruption when updating existing entries (duplicate keys in access order).
- Fixed potential null pointer exception in progress command's ANSI color wrapping.
- Fixed type casting issues in progress and start commands.

## [0.1.2] - 2026-01-04

### Added
- **Multi-Agent Orchestrator**: Introduced a new orchestration layer inspired by Gastown.
  - **Mayor Agent**: New role for task coordination and assignment.
  - **Worker Agent**: Parallelized execution engine for faster implementation.
  - **Witness Agent**: Health monitoring role to detect stuck or timed-out agents.
- **`spectra start` Command**: New CLI command to launch the orchestrator with configurable worker counts (`--workers`).
- **Convoy System**: Batch management for grouped tasks to enable better parallel orchestration.

### Changed
- Refactored implementation logic to be modular and reusable across single-agent and multi-agent execution.
- Renamed `docs` directory to `doc` to follow Dart Pub layout conventions.

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
