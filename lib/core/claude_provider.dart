import 'dart:convert';

import '../utils/http_utils.dart';
import 'llm_provider.dart';

/// Claude (Anthropic) LLM provider implementation.
///
/// Uses the Anthropic Messages API with automatic retry and timeout handling.
class ClaudeProvider implements LLMProvider {
  static const String _defaultModel = 'claude-sonnet-4-5';
  static const List<String> _availableModels = [
    'claude-sonnet-4-5',
    'claude-opus-4-5',
    'claude-haiku-4-5',
    'claude-opus-4-1',
    'claude-sonnet-4-0',
    'claude-3-7-sonnet-latest',
    'claude-opus-4-0'
  ];

  final String apiKey;
  final String modelName;
  final Duration timeout;

  /// Creates a new Claude provider.
  ///
  /// [apiKey] - Your Anthropic API key.
  /// [modelName] - The model to use (default: claude-sonnet-4-5).
  /// [timeout] - Request timeout (default: 60s).
  ClaudeProvider({
    required this.apiKey,
    this.modelName = _defaultModel,
    this.timeout = HttpConfig.defaultTimeout,
  });

  @override
  String get name => 'Claude';

  @override
  List<String> get availableModels => _availableModels;

  @override
  String get defaultModel => _defaultModel;

  @override
  Future<String> generateResponse(String prompt,
      {List<String>? context}) async {
    final fullPrompt =
        context != null ? '${context.join('\n')}\n\n$prompt' : prompt;

    final response = await HttpUtils.postWithRetry(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': modelName,
        'max_tokens': 4096,
        'messages': [
          {'role': 'user', 'content': fullPrompt}
        ],
      }),
      timeout: timeout,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] as String;
    } else {
      throw Exception(
          'Failed to generate response from Claude: ${response.body}');
    }
  }
}
