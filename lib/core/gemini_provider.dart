import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

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

  GeminiProvider({required this.apiKey, this.modelName = _defaultModel});

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

    final response = await http.post(
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
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      try {
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      } catch (e) {
        return 'Error parsing Gemini response: $e';
      }
    } else {
      throw Exception(
          'Failed to generate response from Gemini: ${response.body}');
    }
  }
}
