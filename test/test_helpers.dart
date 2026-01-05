import 'package:mocktail/mocktail.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:spectra_cli/core/llm_provider.dart';
import 'package:spectra_cli/services/llm_service.dart';
import 'package:spectra_cli/services/config_service.dart';
import 'package:spectra_cli/models/spectra_config.dart';

/// Mock implementations for testing

class MockLogger extends Mock implements Logger {}

class MockLLMProvider extends Mock implements LLMProvider {}

class MockLLMService extends Mock implements LLMService {}

class MockConfigService extends Mock implements ConfigService {}

/// A fake LLM provider for testing that returns predictable responses.
class FakeLLMProvider implements LLMProvider {
  final String _name;
  final String _response;

  FakeLLMProvider({
    String name = 'FakeProvider',
    String response = 'Fake response',
  })  : _name = name,
        _response = response;

  @override
  String get name => _name;

  @override
  List<String> get availableModels => ['fake-model-1', 'fake-model-2'];

  @override
  String get defaultModel => 'fake-model-1';

  @override
  Future<String> generateResponse(String prompt,
      {List<String>? context}) async {
    return _response;
  }
}

/// A fake config for testing.
SpectraConfig createTestConfig({
  String? geminiKey,
  String? openaiKey,
  String? claudeKey,
  String? preferredProvider,
}) {
  return SpectraConfig(
    geminiKey: geminiKey ?? 'test-gemini-key',
    openaiKey: openaiKey,
    claudeKey: claudeKey,
    preferredProvider: preferredProvider ?? 'gemini',
  );
}
