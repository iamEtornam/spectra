# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-04-30

### Added — Docs/code alignment

- **Interactive execution mode** for `spectra execute`: per-file review
  (`[A] Apply / [E] Edit / [S] Skip / [Q] Quit`, `[E]` opens `$EDITOR`,
  multi-argument values like `code --wait` supported) plus a
  `[Y]/[N]/[E]` commit prompt. Previously the Interactive config value
  silently behaved as Automatic.
- `LLMProvider.model` getter; the LLM response cache is now keyed by the
  concrete model id so two models of one provider never share entries.
- `RuntimeSnapshot` includes a `proof_of_work` map (issue identifier ->
  `proof.md` path).
- Documentation: `doc/context-engineering.md` and `doc/orchestration.md`
  written (previously empty); all doc pages linked from `docs.json`;
  testing/security/commands guides refreshed to match the code.

### Fixed

- **Secure storage cipher**: keystream is now SHA-256 counter-mode over
  (key, IV, block counter) instead of a `Random` PRNG seeded by a byte
  sum. Legacy `creds.enc` files are decrypted via fallback and
  transparently re-encrypted. Writes are atomic (write-then-rename),
  `.secure` is chmod 700/600 on POSIX, and corrupt key/creds files
  degrade to an empty config with a warning instead of crashing.
- **Stuck-agent recovery**: workers marked `stuck` by the Witness are now
  released and reset to idle, and stale completions from orphaned
  in-flight LLM calls can no longer clobber a reassigned task.
- **`agent.max_turns` is enforced**: scheduler continuations stop at the
  limit, tracked as successful turns so failure retries do not deplete
  the budget. Unsupported `agent.runner` values are rejected at
  validation instead of silently running the LLM runner.
- `tracker.kind` defaults to `local_plan` in config (not just the
  scaffold); agent defaults aligned with docs (`max_concurrent_agents`
  2, `max_turns` 10).
- `spectra execute` skips tasks already marked `status="completed"`, so
  `spectra resume` genuinely continues where it left off.
- Workspace hook output is no longer truncated/dropped when a hook exits
  quickly: streams are drained to completion instead of cancelled on
  exit.
- Test suite runs against an isolated temp home (`useTestHome`) and is
  parallel-safe; the legacy-YAML migration tests are fixed and the
  previously skipped e2e migration test is implemented.

### Added — Symphony work-orchestration model

- **`WORKFLOW.md` policy contract**: repo-owned YAML front matter + Markdown
  prompt body parsed by `WorkflowLoader` into a typed `WorkflowConfig`. Hot
  reload provided by `WorkflowWatcher` (built on `package:watcher`) keeps the
  scheduler in sync without restarts and preserves the last known good config
  on parse failures.
- **Pluggable `IssueTrackerClient` adapters** under `lib/features/tracker/`:
  - `LinearTrackerClient` — Symphony-spec compatible Linear GraphQL adapter
    with pagination, 30s timeout, and categorized error mapping
    (`apiRequest`, `apiStatus`, `graphqlErrors`, `unknownPayload`,
    `missingEndCursor`).
  - `LocalPlanTrackerClient` — adapts existing `.spectra/PLAN.md` tasks (with
    optional `.spectra/ROADMAP.md` checkbox state) into normalized `Issue`s,
    so the existing `spectra plan` -> `spectra start` flow keeps working
    without an external tracker.
  - `TrackerFactory` resolves the adapter from `WorkflowConfig.tracker.kind`.
- **Per-issue git-worktree workspaces** under `lib/features/workspaces/`:
  `WorkspaceManager` sanitizes issue identifiers, enforces root containment,
  creates workspaces with `git worktree add -B spectra/<key>`, and runs
  `after_create` / `before_run` / `after_run` / `before_remove` hooks via
  `bash -lc <script>` with the configured timeout. Falls back to plain
  directories when the project is not a git repo.
- **`AgentRunner` abstraction** under `lib/features/runner/`. Default
  `LlmAgentRunner` reuses Spectra's existing `LLMProvider` stack and parses
  `<file_content>` blocks into the per-issue worktree. A strict `PromptRenderer`
  supports `{{ issue.* }}`, `{{ attempt }}`, `{% if %}`, `{% for %}`, and fails
  on unknown variables/filters per spec.
- **Single-authority `Scheduler`** under `lib/features/orchestration/`. Owns
  `running`, `claimed`, `retryAttempts`, `completed`, and `CodexTotals` maps;
  reconciles tracker state and detects stalls before each tick; exponential
  failure backoff capped by `agent.max_retry_backoff_ms` and 1s continuation
  retries on success.
- **Run-first observability** under `lib/features/observability/`:
  `RuntimeSnapshot` is mirrored to `.spectra/RUNTIME.json` and exposed at
  `GET /api/v1/state`, `GET /api/v1/issue/<identifier>`, and
  `POST /api/v1/refresh`. Added `spectra progress --runs` to print the same
  snapshot in the terminal.
- **Proof-of-work artifacts**: every completed run writes a `proof.md` under
  `.spectra/runs/<run_id>/` with changed files, hook outcomes, retries, and
  recommendation.
- **CLI updates**: `spectra new` now scaffolds a default `WORKFLOW.md`;
  `spectra start` accepts `--workflow <path>` and `--legacy` and auto-routes
  to the new scheduler when `WORKFLOW.md` is present.

### Changed

- `OrchestratorService` now dual-writes `AGENTS.json` (legacy, kept for one
  release) and the new `RUNTIME.json` snapshot so the run-first dashboard
  works whether you run the new scheduler or the legacy convoy mode.
- Dashboard rewritten as a run-first surface; legacy `AGENTS.json` endpoint
  carries a `deprecation` field.

### Added — Dependencies

- `watcher: ^1.2.1` for `WORKFLOW.md` hot reload.

### Notes

- Backward compatible: `OrchestratorService`, `Convoy`, `SpectraTask`,
  `MayorAgent`, `WitnessAgent`, and `WorkerAgent` remain importable.
  `spectra start` falls back to legacy convoy mode when `WORKFLOW.md` is
  missing or `--legacy` is passed.

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
- **CRITICAL**: Fixed deterministic encryption vulnerability in `SecureStorageService`.
  - Encryption now uses random IV (Initialization Vector) for each operation.
  - Same data produces different ciphertext each time (non-deterministic).
  - Resistant to pattern analysis and ciphertext-only attacks.
  - Uses `Random.secure()` for cryptographically secure random generation.
  - Note: Users may need to re-enter API keys once after upgrade.
- Fixed null home directory handling in `ConfigService`, `SecureStorageService`, and `LLMService`.
  - Now throws descriptive `StateError` if HOME/USERPROFILE not set.
  - Prevents creation of invalid `"null/.spectra"` paths.
  - `LLMService` now validates home directory when caching is enabled.
- Fixed case-sensitive provider name lookup in `ConfigCommand`.
  - Legacy v0.1.4 configs with capitalized provider names (e.g., "Gemini") now work correctly.
  - Provider names automatically normalized to lowercase during deserialization.
  - Prevents `indexOf()` returning -1 and causing incorrect UI selections.
  - Handles whitespace trimming for robustness.

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
