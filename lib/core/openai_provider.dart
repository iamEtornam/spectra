import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

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

  OpenAIProvider({required this.apiKey, this.modelName = _defaultModel});

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

    final response = await http.post(
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
