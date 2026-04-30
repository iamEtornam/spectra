import 'dart:io';

import 'package:interact/interact.dart';
import 'package:mason_logger/mason_logger.dart';

import 'base_command.dart';

class NewCommand extends SpectraCommand {
  @override
  final name = 'new';
  @override
  final description = 'Interactive onboarding to create a new Spectra project.';

  NewCommand({required super.logger});

  @override
  Future<void> run() async {
    logger.info(
      lightCyan.wrap('''
  ███████╗██████╗ ███████╗ ██████╗████████╗██████╗  █████╗ 
  ██╔════╝██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔══██╗
  ███████╗██████╔╝█████╗  ██║        ██║   ██████╔╝███████║
  ╚════██║██╔═══╝ ██╔══╝  ██║        ██║   ██╔══██╗██╔══██║
  ███████║██║     ███████╗╚██████╗   ██║   ██║  ██║██║  ██║
  ╚══════╝╚═╝     ╚══════╝ ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝
''')!,
    );

    logger.info('Welcome to Spectra! Let\'s set up your project.');

    final projectName = Select(
      prompt: 'What is your project name?',
      options: ['Spectra App', 'My Awesome CLI', 'Custom'],
    ).interact();

    final actualName = projectName == 2
        ? Input(prompt: 'Enter custom project name:').interact()
        : ['Spectra App', 'My Awesome CLI'][projectName];

    final description = Input(
      prompt: 'Briefly describe your project:',
    ).interact();

    final stack = Select(
      prompt: 'What is your tech stack?',
      options: ['Dart/CLI', 'Flutter/Mobile', 'React/Web', 'Other'],
    ).interact();

    final actualStack = [
      'Dart/CLI',
      'Flutter/Mobile',
      'React/Web',
      'Other',
    ][stack];

    logger.info('\nSummary:');
    logger.info('Project: $actualName');
    logger.info('Description: $description');
    logger.info('Stack: $actualStack');

    final confirm = Confirm(
      prompt: 'Initialize .spectra directory?',
    ).interact();

    if (confirm) {
      _initializeSpectra(actualName, description, actualStack);
      logger.success('Spectra initialized successfully!');
    } else {
      logger.info('Initialization cancelled.');
    }
  }

  void _initializeSpectra(String name, String description, String stack) {
    final spectraDir = Directory('.spectra');
    if (!spectraDir.existsSync()) {
      spectraDir.createSync();
    }

    final projectFile = File('.spectra/PROJECT.md');
    projectFile.writeAsStringSync('''
# PROJECT: $name

## Vision
$description

## Tech Stack
- $stack

## Constraints
- Small-to-medium project (1-50 files)
''');

    final roadmapFile = File('.spectra/ROADMAP.md');
    roadmapFile.writeAsStringSync('''
# ROADMAP

## Phase 1: MVP
- [ ] Core functionality setup
- [ ] Initial project structure
''');

    final stateFile = File('.spectra/STATE.md');
    stateFile.writeAsStringSync('# STATE\n\n- Project initialized.');

    final planFile = File('.spectra/PLAN.md');
    planFile.writeAsStringSync('# PLAN\n\n<!-- No tasks yet -->');

    final summaryFile = File('.spectra/SUMMARY.md');
    summaryFile.writeAsStringSync('# SUMMARY\n\nProject started.');

    final issuesFile = File('.spectra/ISSUES.md');
    issuesFile.writeAsStringSync('# ISSUES\n\nNo issues yet.');

    final workflowFile = File('WORKFLOW.md');
    if (!workflowFile.existsSync()) {
      workflowFile.writeAsStringSync(_defaultWorkflow(name));
    }
  }

  String _defaultWorkflow(String projectName) {
    return '''
---
tracker:
  kind: local_plan
polling:
  interval_ms: 15000
workspace:
  root: .spectra/workspaces
agent:
  runner: llm
  max_concurrent_agents: 2
  max_turns: 10
hooks:
  before_run: |
    git fetch --all --quiet || true
---
You are working on {{ issue.identifier }} for $projectName.

## Issue
{{ issue.title }}

{{ issue.description }}

## Instructions
- Implement the change end-to-end inside the workspace.
- Run any verification steps documented in the issue description.
- Return the full content of each modified file wrapped in
  `<file_content path="path/to/file"> ... </file_content>` tags relative to
  the workspace root.
- Do not write outside the workspace.
''';
  }
}
