import 'dart:convert';

import '../utils/http_utils.dart';
import 'llm_provider.dart';

/// Gemini LLM provider implementation.
///
/// Uses the Google Generative AI REST API with automatic retry and timeout handling.
class GeminiProvider implements LLMProvider {
  static const String _defaultModel = 'gemini-3-pro-preview';
  static const List<String> _availableModels = [
    'gemini-3-pro-preview',
    'gemini-3-flash-preview',
    'gemini-2.5-pro',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
  ];

  final String apiKey;
  final String modelName;
  final Duration timeout;

  /// Creates a new Gemini provider.
  ///
  /// [apiKey] - Your Google AI API key.
  /// [modelName] - The model to use (default: gemini-3-pro-preview).
  /// [timeout] - Request timeout (default: 60s).
  GeminiProvider({
    required this.apiKey,
    this.modelName = _defaultModel,
    this.timeout = HttpConfig.defaultTimeout,
  });

  @override
  String get name => 'Gemini';

  @override
  List<String> get availableModels => _availableModels;

  @override
  String get defaultModel => _defaultModel;

  @override
  Future<String> generateResponse(String prompt,
      {List<String>? context}) async {
    final fullPrompt =
        context != null ? '${context.join('\n')}\n\n$prompt' : prompt;

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent');

    final response = await HttpUtils.postWithRetry(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': fullPrompt}
            ]
          }
        ]
      }),
      timeout: timeout,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      try {
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      } catch (e) {
        throw Exception('Error parsing Gemini response: $e');
      }
    } else {
      throw Exception(
          'Failed to generate response from Gemini: ${response.body}');
    }
  }
}
