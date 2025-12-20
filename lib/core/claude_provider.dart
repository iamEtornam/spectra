import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

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

  ClaudeProvider({required this.apiKey, this.modelName = _defaultModel});

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

    final response = await http.post(
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
