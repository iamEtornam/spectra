import '../tracker/issue.dart';
import '../workflow/workflow_failure.dart';

/// Renders a workflow prompt template for one issue attempt.
///
/// Supports a small Liquid-compatible subset that's sufficient for Symphony
/// templates:
///
/// * `{{ var.path }}` interpolation.
/// * `{% if expr %} ... {% else %} ... {% endif %}` conditionals using
///   variable truthiness.
/// * `{% for item in collection %} ... {% endfor %}` iteration over lists.
///
/// Strict rules:
///
/// * Unknown variables fail with [WorkflowFailureCode.templateRenderError].
/// * Unknown filters/tags fail with [WorkflowFailureCode.templateParseError].
class PromptRenderer {
  /// Creates a prompt renderer.
  const PromptRenderer();

  /// Renders [template] using [issue] and [attempt].
  ///
  /// Throws [WorkflowException] when rendering fails.
  String render(String template, {required Issue issue, int? attempt}) {
    if (template.trim().isEmpty) {
      return 'You are working on an issue from Spectra.';
    }
    final scope = <String, Object?>{
      'issue': issue.toJson(),
      'attempt': attempt,
    };
    final tokens = _tokenize(template);
    final buffer = StringBuffer();
    var index = 0;
    while (index < tokens.length) {
      index = _renderTokens(
        tokens,
        index,
        scope,
        buffer,
        terminators: const <String>{},
      );
    }
    return buffer.toString();
  }

  int _renderTokens(
    List<_Token> tokens,
    int start,
    Map<String, Object?> scope,
    StringBuffer buffer, {
    required Set<String> terminators,
  }) {
    var i = start;
    while (i < tokens.length) {
      final token = tokens[i];
      if (token is _LiteralToken) {
        buffer.write(token.text);
        i += 1;
        continue;
      }
      if (token is _VariableToken) {
        buffer.write(_stringify(_resolve(token.expression, scope)));
        i += 1;
        continue;
      }
      if (token is _TagToken) {
        if (terminators.contains(token.tag)) {
          return i;
        }
        if (token.tag == 'if') {
          i = _handleIf(tokens, i, scope, buffer);
          continue;
        }
        if (token.tag == 'for') {
          i = _handleFor(tokens, i, scope, buffer);
          continue;
        }
        throw WorkflowException(
          WorkflowFailureCode.templateParseError,
          'Unsupported template tag: {% ${token.raw} %}',
        );
      }
      i += 1;
    }
    return i;
  }

  int _handleIf(
    List<_Token> tokens,
    int start,
    Map<String, Object?> scope,
    StringBuffer buffer,
  ) {
    final ifToken = tokens[start] as _TagToken;
    final condition = ifToken.argument;
    if (condition.isEmpty) {
      throw const WorkflowException(
        WorkflowFailureCode.templateParseError,
        '{% if %} requires a condition expression.',
      );
    }
    final value = _resolve(condition, scope);
    final truthy = _isTruthy(value);

    final ifBranch = StringBuffer();
    final elseBranch = StringBuffer();

    var i = start + 1;
    var inElse = false;
    while (i < tokens.length) {
      final token = tokens[i];
      if (token is _TagToken) {
        if (token.tag == 'endif') {
          if (truthy) {
            buffer.write(ifBranch.toString());
          } else {
            buffer.write(elseBranch.toString());
          }
          return i + 1;
        }
        if (token.tag == 'else') {
          inElse = true;
          i += 1;
          continue;
        }
      }

      final target = inElse ? elseBranch : ifBranch;
      if (token is _LiteralToken) {
        target.write(token.text);
        i += 1;
        continue;
      }
      if (token is _VariableToken) {
        target.write(_stringify(_resolve(token.expression, scope)));
        i += 1;
        continue;
      }
      // Nested tag: render through a temporary buffer.
      final tempBuffer = StringBuffer();
      i = _renderTokens(
        tokens,
        i,
        scope,
        tempBuffer,
        terminators: const <String>{'endif', 'else'},
      );
      target.write(tempBuffer.toString());
    }
    throw const WorkflowException(
      WorkflowFailureCode.templateParseError,
      '{% if %} block was not closed with {% endif %}.',
    );
  }

  int _handleFor(
    List<_Token> tokens,
    int start,
    Map<String, Object?> scope,
    StringBuffer buffer,
  ) {
    final forToken = tokens[start] as _TagToken;
    final match = RegExp(
      r'^([A-Za-z_][A-Za-z0-9_]*)\s+in\s+(.+)$',
    ).firstMatch(forToken.argument);
    if (match == null) {
      throw WorkflowException(
        WorkflowFailureCode.templateParseError,
        '{% for %} expects "varname in expression": ${forToken.argument}',
      );
    }
    final varName = match.group(1)!;
    final expression = match.group(2)!.trim();
    final iterable = _resolve(expression, scope);
    if (iterable is! Iterable) {
      throw WorkflowException(
        WorkflowFailureCode.templateRenderError,
        '{% for %} expression "$expression" did not evaluate to an iterable.',
      );
    }

    // Find matching endfor.
    final body = <_Token>[];
    var depth = 1;
    var i = start + 1;
    while (i < tokens.length && depth > 0) {
      final token = tokens[i];
      if (token is _TagToken) {
        if (token.tag == 'for') depth += 1;
        if (token.tag == 'endfor') {
          depth -= 1;
          if (depth == 0) break;
        }
      }
      body.add(token);
      i += 1;
    }
    if (depth != 0) {
      throw const WorkflowException(
        WorkflowFailureCode.templateParseError,
        '{% for %} block was not closed with {% endfor %}.',
      );
    }

    for (final item in iterable) {
      final loopScope = Map<String, Object?>.from(scope)..[varName] = item;
      var j = 0;
      while (j < body.length) {
        j = _renderTokens(
          body,
          j,
          loopScope,
          buffer,
          terminators: const <String>{},
        );
      }
    }
    return i + 1;
  }

  Object? _resolve(String expression, Map<String, Object?> scope) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) {
      throw const WorkflowException(
        WorkflowFailureCode.templateRenderError,
        'Empty template expression.',
      );
    }

    if (trimmed.contains('|')) {
      throw WorkflowException(
        WorkflowFailureCode.templateParseError,
        'Template filters are not supported: $trimmed',
      );
    }

    // String literal.
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      return trimmed.substring(1, trimmed.length - 1);
    }

    // Numeric literal.
    final numeric = num.tryParse(trimmed);
    if (numeric != null) return numeric;

    // Boolean / null literals.
    switch (trimmed) {
      case 'true':
        return true;
      case 'false':
        return false;
      case 'nil' || 'null':
        return null;
    }

    final parts = trimmed.split('.');
    if (!scope.containsKey(parts.first)) {
      throw WorkflowException(
        WorkflowFailureCode.templateRenderError,
        'Unknown template variable: ${parts.first}',
      );
    }
    Object? current = scope[parts.first];
    for (var idx = 1; idx < parts.length; idx += 1) {
      final key = parts[idx];
      if (current is Map) {
        if (!current.containsKey(key)) {
          throw WorkflowException(
            WorkflowFailureCode.templateRenderError,
            'Unknown template path: $trimmed',
          );
        }
        current = current[key];
      } else {
        throw WorkflowException(
          WorkflowFailureCode.templateRenderError,
          'Cannot resolve "$key" on non-object: $trimmed',
        );
      }
    }
    return current;
  }

  bool _isTruthy(Object? value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  String _stringify(Object? value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  List<_Token> _tokenize(String template) {
    final tokens = <_Token>[];
    final pattern = RegExp(r'\{\{\s*(.*?)\s*\}\}|\{%\s*(.*?)\s*%\}');
    var lastEnd = 0;
    for (final match in pattern.allMatches(template)) {
      if (match.start > lastEnd) {
        tokens.add(_LiteralToken(template.substring(lastEnd, match.start)));
      }
      final variable = match.group(1);
      final tag = match.group(2);
      if (variable != null) {
        tokens.add(_VariableToken(variable.trim()));
      } else if (tag != null) {
        final raw = tag.trim();
        final spaceIdx = raw.indexOf(RegExp(r'\s'));
        final tagName = spaceIdx == -1 ? raw : raw.substring(0, spaceIdx);
        final argument = spaceIdx == -1
            ? ''
            : raw.substring(spaceIdx + 1).trim();
        tokens.add(_TagToken(raw: raw, tag: tagName, argument: argument));
      }
      lastEnd = match.end;
    }
    if (lastEnd < template.length) {
      tokens.add(_LiteralToken(template.substring(lastEnd)));
    }
    return tokens;
  }
}

sealed class _Token {
  const _Token();
}

class _LiteralToken extends _Token {
  final String text;
  const _LiteralToken(this.text);
}

class _VariableToken extends _Token {
  final String expression;
  const _VariableToken(this.expression);
}

class _TagToken extends _Token {
  final String raw;
  final String tag;
  final String argument;
  const _TagToken({
    required this.raw,
    required this.tag,
    required this.argument,
  });
}
