import 'dart:convert';

import '../utils/http_utils.dart';
import 'llm_provider.dart';

/// Grok (xAI) LLM provider implementation.
///
/// Uses the xAI Chat API with automatic retry and timeout handling.
class GrokProvider implements LLMProvider {
  static const String _defaultModel = 'grok-2';
  static const List<String> _availableModels = [
    'grok-3',
    'grok-3-mini',
    'grok-4',
    'grok-4-fast-reasoning',
    'grok-4-1-fast-reasoning',
  ];

  final String apiKey;
  final String modelName;
  final Duration timeout;

  /// Creates a new Grok provider.
  ///
  /// [apiKey] - Your xAI API key.
  /// [modelName] - The model to use (default: grok-2).
  /// [timeout] - Request timeout (default: 60s).
  GrokProvider({
    required this.apiKey,
    this.modelName = _defaultModel,
    this.timeout = HttpConfig.defaultTimeout,
  });

  @override
  String get name => 'Grok';

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
      Uri.parse('https://api.x.ai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': modelName,
        'messages': [
          {'role': 'user', 'content': fullPrompt}
        ],
      }),
      timeout: timeout,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception(
          'Failed to generate response from Grok: ${response.body}');
    }
  }
}
