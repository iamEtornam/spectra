import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider.dart';

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

  GrokProvider({required this.apiKey, this.modelName = _defaultModel});

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

    final response = await http.post(
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
