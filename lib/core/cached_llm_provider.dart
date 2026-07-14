import '../services/llm_cache.dart';
import 'llm_provider.dart';

/// A wrapper that adds caching capability to any LLM provider.
///
/// This decorator pattern allows transparent caching of LLM responses
/// without modifying the underlying provider implementations.
class CachedLLMProvider implements LLMProvider {
  final LLMProvider _delegate;
  final LLMCache _cache;

  int _cacheHits = 0;
  int _cacheMisses = 0;

  /// Creates a cached wrapper around an existing provider.
  ///
  /// [delegate] - The underlying LLM provider to wrap.
  /// [cache] - The cache instance to use (shared across providers if desired).
  CachedLLMProvider({required LLMProvider delegate, required LLMCache cache})
    : _delegate = delegate,
      _cache = cache;

  @override
  String get name => _delegate.name;

  @override
  String get model => _delegate.model;

  @override
  List<String> get availableModels => _delegate.availableModels;

  @override
  String get defaultModel => _delegate.defaultModel;

  @override
  Future<String> generateResponse(
    String prompt, {
    List<String>? context,
  }) async {
    // Try cache first. Keyed by the concrete model, not the provider name,
    // so e.g. two Claude models never share entries.
    final cached = _cache.get(prompt, model, context: context);
    if (cached != null) {
      _cacheHits++;
      return cached;
    }

    // Cache miss - call the actual provider
    _cacheMisses++;
    final response = await _delegate.generateResponse(prompt, context: context);

    // Cache the response
    _cache.put(prompt, model, response, context: context);

    return response;
  }

  /// Returns cache statistics for this provider.
  Map<String, dynamic> get stats => {
    'provider': name,
    'cacheHits': _cacheHits,
    'cacheMisses': _cacheMisses,
    'hitRate': _cacheHits + _cacheMisses > 0
        ? (_cacheHits / (_cacheHits + _cacheMisses) * 100).toStringAsFixed(1)
        : '0.0',
    ..._cache.stats,
  };
}
