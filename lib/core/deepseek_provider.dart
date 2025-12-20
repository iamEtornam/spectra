import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider.dart';

class DeepSeekProvider implements LLMProvider {
  static const String _defaultModel = 'deepseek-chat';
  static const List<String> _availableModels = [
    'deepseek-chat',
    'deepseek-reasoner',
  ];

  final String apiKey;
  final String modelName;

  DeepSeekProvider({required this.apiKey, this.modelName = _defaultModel});

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

    final response = await http.post(
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
