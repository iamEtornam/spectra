import 'dart:convert';

import '../utils/http_utils.dart';
import 'llm_provider.dart';

/// OpenAI LLM provider implementation.
///
/// Uses the OpenAI Chat Completions API with automatic retry and timeout handling.
class OpenAIProvider implements LLMProvider {
  static const String _defaultModel = 'gpt-5.2';
  static const List<String> _availableModels = [
    'gpt-5.2',
    'gpt-5-mini-2025-08-07',
    'gpt-5-nano-2025-08-07',
    'gpt-4.1-2025-04-14',
    'gpt-oss-120b'
  ];

  final String apiKey;
  final String modelName;
  final Duration timeout;

  /// Creates a new OpenAI provider.
  ///
  /// [apiKey] - Your OpenAI API key.
  /// [modelName] - The model to use (default: gpt-5.2).
  /// [timeout] - Request timeout (default: 60s).
  OpenAIProvider({
    required this.apiKey,
    this.modelName = _defaultModel,
    this.timeout = HttpConfig.defaultTimeout,
  });

  @override
  String get name => 'OpenAI';

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
      Uri.parse('https://api.openai.com/v1/chat/completions'),
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
          'Failed to generate response from OpenAI: ${response.body}');
    }
  }
}
