/// Defines how tasks should be executed in Spectra.
///
/// This allows users to use Spectra purely for planning and task management,
/// without requiring AI-generated code implementation.
enum ExecutionMode {
  /// Tasks are automatically implemented by AI.
  ///
  /// When this mode is active:
  /// - `spectra execute` generates code using LLM
  /// - `spectra start` spawns workers that generate code
  /// - Files are automatically written
  /// - Git commits are automatic
  ///
  /// Best for:
  /// - Rapid prototyping
  /// - Greenfield projects
  /// - Autonomous development
  automatic,

  /// Tasks are planned by AI but implemented manually by the user.
  ///
  /// When this mode is active:
  /// - `spectra plan` generates task breakdown (AI)
  /// - `spectra execute` shows tasks but doesn't generate code
  /// - User implements tasks manually
  /// - User commits when ready
  ///
  /// Best for:
  /// - Developers who want AI planning but manual control
  /// - Code review before implementation
  /// - Learning from AI suggestions
  /// - Complex tasks requiring human judgment
  manual,

  /// Interactive mode: AI generates code, user reviews before applying.
  ///
  /// When this mode is active:
  /// - AI generates code suggestions
  /// - User reviews each file before writing
  /// - User can edit suggestions
  /// - User approves commits
  ///
  /// Best for:
  /// - Production code
  /// - Critical systems
  /// - Learning from AI
  /// - Hybrid workflow
  interactive;

  /// Returns a human-readable description of this execution mode.
  String get description {
    return switch (this) {
      ExecutionMode.automatic => 'AI generates and writes code automatically',
      ExecutionMode.manual => 'AI plans tasks, user implements code manually',
      ExecutionMode.interactive =>
        'AI generates code, user reviews and approves',
    };
  }

  /// Returns examples of when to use this mode.
  List<String> get useCases {
    return switch (this) {
      ExecutionMode.automatic => [
        'Rapid prototyping',
        'Greenfield projects',
        'Boilerplate generation',
        'Quick MVPs',
      ],
      ExecutionMode.manual => [
        'Learning project architecture',
        'Complex business logic',
        'Manual code review required',
        'Using IDE/Copilot for implementation',
      ],
      ExecutionMode.interactive => [
        'Production code',
        'Critical systems',
        'Code review workflow',
        'Teaching/learning scenarios',
      ],
    };
  }

  /// Returns the level of AI automation in this mode.
  String get automationLevel {
    return switch (this) {
      ExecutionMode.automatic => 'Full automation',
      ExecutionMode.manual => 'Planning only',
      ExecutionMode.interactive => 'Semi-automatic',
    };
  }

  /// Whether this mode generates code automatically.
  bool get generatesCode {
    return switch (this) {
      ExecutionMode.automatic => true,
      ExecutionMode.manual => false,
      ExecutionMode.interactive => true,
    };
  }

  /// Whether this mode requires user approval.
  bool get requiresApproval {
    return switch (this) {
      ExecutionMode.automatic => false,
      ExecutionMode.manual => true,
      ExecutionMode.interactive => true,
    };
  }
}
