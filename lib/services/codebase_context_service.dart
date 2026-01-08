import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// Service that provides codebase context to agents.
///
/// This service gathers relevant information about the codebase including:
/// - Project structure and organization
/// - Living Memory files (.spectra/)
/// - Related files and dependencies
/// - Common patterns and conventions
class CodebaseContextService {
  final Logger logger;

  CodebaseContextService({required this.logger});

  /// Gets comprehensive codebase context for a set of target files.
  ///
  /// Returns a formatted string with:
  /// - Project overview from Living Memory
  /// - Codebase structure
  /// - Related files and dependencies
  /// - Patterns and conventions
  String getCodebaseContext(List<String> targetFiles) {
    final buffer = StringBuffer();

    // 1. Living Memory Context
    buffer.writeln('=== PROJECT CONTEXT (Living Memory) ===');
    buffer.writeln(_getLivingMemoryContext());
    buffer.writeln();

    // 2. Codebase Structure
    buffer.writeln('=== CODEBASE STRUCTURE ===');
    buffer.writeln(_getCodebaseStructure());
    buffer.writeln();

    // 3. Related Files Context
    buffer.writeln('=== RELATED FILES & DEPENDENCIES ===');
    buffer.writeln(_getRelatedFilesContext(targetFiles));
    buffer.writeln();

    // 4. Patterns and Conventions
    buffer.writeln('=== PATTERNS & CONVENTIONS ===');
    buffer.writeln(_getPatternsAndConventions(targetFiles));
    buffer.writeln();

    return buffer.toString();
  }

  /// Gets context from Living Memory files (.spectra/).
  String _getLivingMemoryContext() {
    final buffer = StringBuffer();

    // Check if .spectra directory exists
    final spectraDir = Directory('.spectra');
    if (!spectraDir.existsSync()) {
      return 'No .spectra directory found. Project may not be initialized.';
    }

    // PROJECT.md - Project vision and goals
    final projectFile = File('.spectra/PROJECT.md');
    if (projectFile.existsSync()) {
      try {
        buffer.writeln('PROJECT.md:');
        buffer.writeln(projectFile.readAsStringSync());
        buffer.writeln();
      } catch (e) {
        buffer.writeln('PROJECT.md: (could not read: $e)');
      }
    }

    // ROADMAP.md - Overall project roadmap
    final roadmapFile = File('.spectra/ROADMAP.md');
    if (roadmapFile.existsSync()) {
      try {
        final roadmap = roadmapFile.readAsStringSync();
        // Only include first 500 chars to avoid overwhelming context
        buffer.writeln('ROADMAP.md (excerpt):');
        buffer.writeln(roadmap.length > 500
            ? '${roadmap.substring(0, 500)}...'
            : roadmap);
        buffer.writeln();
      } catch (e) {
        buffer.writeln('ROADMAP.md: (could not read: $e)');
      }
    }

    // PLAN.md - Current execution plan
    final planFile = File('.spectra/PLAN.md');
    if (planFile.existsSync()) {
      try {
        final plan = planFile.readAsStringSync();
        buffer.writeln('PLAN.md (current tasks):');
        // Extract task summaries
        final taskRegex = RegExp(r'<task[^>]*>\s*<n>(.*?)</n>', dotAll: true);
        final tasks = taskRegex.allMatches(plan);
        for (final task in tasks.take(5)) {
          buffer.writeln('- ${task.group(1)}');
        }
        if (tasks.length > 5) {
          buffer.writeln('... and ${tasks.length - 5} more tasks');
        }
        buffer.writeln();
      } catch (e) {
        buffer.writeln('PLAN.md: (could not read: $e)');
      }
    }

    // STATE.md - Recent project state
    final stateFile = File('.spectra/STATE.md');
    if (stateFile.existsSync()) {
      try {
        final state = stateFile.readAsStringSync();
        // Get last 10 lines
        final lines = state.split('\n');
        final recentLines = lines.length > 10
            ? lines.sublist(lines.length - 10)
            : lines;
        buffer.writeln('STATE.md (recent activity):');
        buffer.writeln(recentLines.join('\n'));
        buffer.writeln();
      } catch (e) {
        buffer.writeln('STATE.md: (could not read: $e)');
      }
    }

    return buffer.toString();
  }

  /// Gets an overview of the codebase structure.
  String _getCodebaseStructure() {
    final buffer = StringBuffer();

    // Get lib/ directory structure
    final libDir = Directory('lib');
    if (libDir.existsSync()) {
      try {
        buffer.writeln('lib/ structure:');
        _writeDirectoryTree(libDir, buffer, maxDepth: 3);
        buffer.writeln();
      } catch (e) {
        buffer.writeln('lib/ structure: (could not read: $e)');
        buffer.writeln();
      }
    } else {
      buffer.writeln('lib/ directory does not exist yet (will be created as needed).');
      buffer.writeln();
    }

    // Get pubspec.yaml for dependencies
    final pubspecFile = File('pubspec.yaml');
    if (pubspecFile.existsSync()) {
      try {
        buffer.writeln('Dependencies (pubspec.yaml):');
        final content = pubspecFile.readAsStringSync();
        // Extract dependencies section
        final depsMatch = RegExp(r'dependencies:\s*\n((?:[^\n]*\n)*)')
            .firstMatch(content);
        if (depsMatch != null) {
          buffer.writeln(depsMatch.group(1));
        }
        buffer.writeln();
      } catch (e) {
        buffer.writeln('pubspec.yaml: (could not read: $e)');
      }
    } else {
      buffer.writeln('pubspec.yaml does not exist yet.');
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Writes a directory tree representation.
  void _writeDirectoryTree(
    Directory dir,
    StringBuffer buffer, {
    int depth = 0,
    int maxDepth = 3,
    String prefix = '',
  }) {
    if (depth > maxDepth) return;
    if (!dir.existsSync()) return;

    try {
      List<FileSystemEntity> entities;
      try {
        entities = dir.listSync();
      } catch (e) {
        // Directory might not exist or might not be accessible
        return;
      }

      entities.sort((a, b) {
        // Directories first, then files
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });

      for (var i = 0; i < entities.length; i++) {
        final entity = entities[i];
        final isLast = i == entities.length - 1;
        final currentPrefix = isLast ? '└── ' : '├── ';
        final nextPrefix = isLast ? '    ' : '│   ';

        final name = entity.path.split(Platform.pathSeparator).last;
        buffer.writeln('$prefix$currentPrefix$name');

        if (entity is Directory && depth < maxDepth) {
          try {
            _writeDirectoryTree(
              entity,
              buffer,
              depth: depth + 1,
              maxDepth: maxDepth,
              prefix: '$prefix$nextPrefix',
            );
          } catch (e) {
            // Skip directories that can't be accessed
          }
        }
      }
    } catch (e) {
      // Ignore permission errors and missing directories
      buffer.writeln('$prefix└── (error reading directory: $e)');
    }
  }

  /// Gets context about related files and dependencies.
  String _getRelatedFilesContext(List<String> targetFiles) {
    final buffer = StringBuffer();
    final relatedFiles = <String>{};

    for (final targetFile in targetFiles) {
      final file = File(targetFile);
      if (!file.existsSync()) continue;

      try {
        final content = file.readAsStringSync();

        // Find imports/exports
        final importRegex = RegExp(
          r"import\s+['""]([^'""]+)['""]",
          multiLine: true,
        );
        final imports = importRegex.allMatches(content);

        if (imports.isNotEmpty) {
          buffer.writeln('$targetFile imports:');
          for (final importMatch in imports.take(10)) {
            final importPath = importMatch.group(1)!;
            // Convert package: imports to lib/ paths
            String? filePath;
            if (importPath.startsWith('package:')) {
              final packagePath = importPath.replaceFirst('package:', '');
              // Handle package imports - check pubspec.yaml name
              final pubspecFile = File('pubspec.yaml');
              if (pubspecFile.existsSync()) {
                final pubspecContent = pubspecFile.readAsStringSync();
                final nameMatch = RegExp(r'^name:\s*(.+)$', multiLine: true)
                    .firstMatch(pubspecContent);
                if (nameMatch != null) {
                  final packageName = nameMatch.group(1)!.trim();
                  if (packagePath.startsWith('$packageName/')) {
                    final relativePath =
                        packagePath.replaceFirst('$packageName/', '');
                    filePath = 'lib/$relativePath.dart';
                  } else {
                    filePath = 'lib/$packagePath.dart';
                  }
                } else {
                  filePath = 'lib/$packagePath.dart';
                }
              } else {
                filePath = 'lib/$packagePath.dart';
              }
            } else if (importPath.startsWith('../') ||
                importPath.startsWith('./')) {
              // Relative import - resolve relative to current file
              try {
                final resolved = file.parent.uri.resolve(importPath).path;
                filePath = resolved;
              } catch (e) {
                // Skip invalid paths
              }
            } else {
              // Assume it's a relative import from lib/
              filePath = 'lib/$importPath.dart';
            }

            if (filePath != null && File(filePath).existsSync()) {
              relatedFiles.add(filePath);
              buffer.writeln('  - $importPath -> $filePath');
            }
          }
          buffer.writeln();
        }

        // Find exports
        final exportRegex = RegExp(
          r"export\s+['""]([^'""]+)['""]",
          multiLine: true,
        );
        final exports = exportRegex.allMatches(content);
        if (exports.isNotEmpty) {
          buffer.writeln('$targetFile exports:');
          for (final exportMatch in exports.take(5)) {
            buffer.writeln('  - ${exportMatch.group(1)}');
          }
          buffer.writeln();
        }
      } catch (e) {
        // Skip files that can't be read
      }
    }

    // Include content of key related files (limit to avoid token bloat)
    if (relatedFiles.isNotEmpty) {
      buffer.writeln('Key related files (first 200 lines each):');
      for (final relatedFile in relatedFiles.take(3)) {
        try {
          final file = File(relatedFile);
          if (file.existsSync()) {
            final content = file.readAsStringSync();
            final lines = content.split('\n');
            final excerpt = lines.length > 200
                ? lines.sublist(0, 200).join('\n')
                : content;
            buffer.writeln('--- $relatedFile ---');
            buffer.writeln(excerpt);
            buffer.writeln('---');
          }
        } catch (e) {
          // Skip files that can't be read
        }
      }
    }

    return buffer.toString();
  }

  /// Extracts patterns and conventions from the codebase.
  String _getPatternsAndConventions(List<String> targetFiles) {
    final buffer = StringBuffer();

    // Analyze file naming conventions
    final libDir = Directory('lib');
    List<File> dartFiles = [];
    if (libDir.existsSync()) {
      try {
        dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .take(20)
            .toList();
      } catch (e) {
        // Directory might not be readable or might have been deleted
        dartFiles = [];
      }
    }

    if (dartFiles.isNotEmpty) {
      buffer.writeln('File naming patterns:');
      final patterns = <String>{};
      for (final file in dartFiles) {
        final name = file.path.split(Platform.pathSeparator).last;
        if (name.contains('_')) {
          patterns.add('snake_case');
        } else if (RegExp(r'^[A-Z]').hasMatch(name)) {
          patterns.add('PascalCase');
        }
      }
      buffer.writeln('  - ${patterns.join(', ')}');
      buffer.writeln();
    }

    // Check for common patterns in target files
    for (final targetFile in targetFiles) {
      final file = File(targetFile);
      if (!file.existsSync()) continue;

      try {
        final content = file.readAsStringSync();

        // Check for common Flutter/Dart patterns
        if (content.contains('extends StatelessWidget') ||
            content.contains('extends StatefulWidget')) {
          buffer.writeln('$targetFile uses Flutter widget pattern');
        }
        if (content.contains('class') && content.contains('extends')) {
          buffer.writeln('$targetFile uses class inheritance pattern');
        }
        if (content.contains('@override')) {
          buffer.writeln('$targetFile uses @override annotations');
        }
        if (content.contains('final') && content.contains('const')) {
          buffer.writeln('$targetFile uses immutable patterns (final/const)');
        }
      } catch (e) {
        // Skip
      }
    }

    return buffer.toString();
  }
}
