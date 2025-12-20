abstract class LLMProvider {
  Future<String> generateResponse(String prompt, {List<String>? context});
  String get name;
  List<String> get availableModels;
  String get defaultModel;
}
