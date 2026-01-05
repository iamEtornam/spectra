/// Abstract interface for LLM (Large Language Model) providers.
///
/// This interface defines the contract that all LLM providers must implement
/// to be used with Spectra. Providers handle the actual communication with
/// AI services (OpenAI, Anthropic, Google, etc.).
///
/// ## Implementing a Provider
///
/// To create a new provider, extend this class and implement:
/// - [generateResponse] - The main method for generating AI responses
/// - [name] - Human-readable name of the provider
/// - [availableModels] - List of supported model names
/// - [defaultModel] - The recommended default model
///
/// ## Example
///
/// ```dart
/// class MyProvider implements LLMProvider {
///   @override
///   String get name => 'MyProvider';
///
///   @override
///   List<String> get availableModels => ['model-1', 'model-2'];
///
///   @override
///   String get defaultModel => 'model-1';
///
///   @override
///   Future<String> generateResponse(String prompt, {List<String>? context}) async {
///     // Implementation here
///   }
/// }
/// ```
abstract class LLMProvider {
  /// Generates a response from the LLM based on the given prompt.
  ///
  /// [prompt] - The input prompt to send to the model.
  /// [context] - Optional list of context strings to prepend to the prompt.
  ///
  /// Returns the generated text response.
  ///
  /// Throws [Exception] if the request fails.
  Future<String> generateResponse(String prompt, {List<String>? context});

  /// Human-readable name of this provider (e.g., "OpenAI", "Claude").
  String get name;

  /// List of model names available from this provider.
  List<String> get availableModels;

  /// The default model to use if none is specified.
  String get defaultModel;
}
