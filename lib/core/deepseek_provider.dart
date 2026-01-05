import 'dart:convert';

import '../utils/http_utils.dart';
import 'llm_provider.dart';

/// DeepSeek LLM provider implementation.
///
/// Uses the DeepSeek Chat API with automatic retry and timeout handling.
class DeepSeekProvider implements LLMProvider {
  static const String _defaultModel = 'deepseek-chat';
  static const List<String> _availableModels = [
    'deepseek-chat',
    'deepseek-reasoner',
  ];

  final String apiKey;
  final String modelName;
  final Duration timeout;

  /// Creates a new DeepSeek provider.
  ///
  /// [apiKey] - Your DeepSeek API key.
  /// [modelName] - The model to use (default: deepseek-chat).
  /// [timeout] - Request timeout (default: 60s).
  DeepSeekProvider({
    required this.apiKey,
    this.modelName = _defaultModel,
    this.timeout = HttpConfig.defaultTimeout,
  });

  @override
  String get name => 'DeepSeek';

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
      Uri.parse('https://api.deepseek.com/v1/chat/completions'),
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
          'Failed to generate response from DeepSeek: ${response.body}');
    }
  }
}
