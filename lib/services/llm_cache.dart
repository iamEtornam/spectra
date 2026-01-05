import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// LRU Cache for LLM responses to reduce API costs and improve response times.
///
/// The cache stores responses keyed by a hash of the prompt and context.
/// It supports both in-memory caching and persistent file-based caching.
class LLMCache {
  static const int _defaultMaxEntries = 100;
  static const Duration _defaultTtl = Duration(hours: 24);

  final int maxEntries;
  final Duration ttl;
  final Map<String, _CacheEntry> _cache = {};
  final List<String> _accessOrder = [];
  final File? _persistFile;

  /// Creates a new LLM cache.
  ///
  /// [maxEntries] - Maximum number of entries to keep in cache (LRU eviction).
  /// [ttl] - Time-to-live for cache entries.
  /// [persistPath] - Optional path to persist cache to disk.
  LLMCache({
    this.maxEntries = _defaultMaxEntries,
    this.ttl = _defaultTtl,
    String? persistPath,
  }) : _persistFile = persistPath != null ? File(persistPath) : null {
    _loadFromDisk();
  }

  /// Generates a cache key from the prompt, model, and optional context.
  String _generateKey(String prompt, String model, List<String>? context) {
    final combined = '$model:$prompt:${context?.join('|') ?? ''}';
    final bytes = utf8.encode(combined);
    return sha256.convert(bytes).toString();
  }

  /// Gets a cached response if available and not expired.
  String? get(String prompt, String model, {List<String>? context}) {
    final key = _generateKey(prompt, model, context);
    final entry = _cache[key];

    if (entry == null) {
      return null;
    }

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _remove(key);
      return null;
    }

    // Move to end of access order (most recently used)
    _accessOrder.remove(key);
    _accessOrder.add(key);

    return entry.response;
  }

  /// Caches a response.
  void put(String prompt, String model, String response,
      {List<String>? context}) {
    final key = _generateKey(prompt, model, context);

    // Check if this is an update to an existing entry
    final isUpdate = _cache.containsKey(key);

    // Remove existing key from access order to prevent duplicates
    if (isUpdate) {
      _accessOrder.remove(key);
    }

    // Evict oldest if at capacity (only for new entries)
    if (!isUpdate) {
      while (_cache.length >= maxEntries && _accessOrder.isNotEmpty) {
        final oldest = _accessOrder.removeAt(0);
        _cache.remove(oldest);
      }
    }

    _cache[key] = _CacheEntry(
      response: response,
      expiresAt: DateTime.now().add(ttl),
    );
    _accessOrder.add(key);

    _saveToDisk();
  }

  /// Removes an entry from the cache.
  void _remove(String key) {
    _cache.remove(key);
    _accessOrder.remove(key);
    _saveToDisk();
  }

  /// Clears all cached entries.
  void clear() {
    _cache.clear();
    _accessOrder.clear();
    _saveToDisk();
  }

  /// Returns cache statistics.
  Map<String, dynamic> get stats => {
        'entries': _cache.length,
        'maxEntries': maxEntries,
        'ttlHours': ttl.inHours,
      };

  /// Loads cache from disk if persist file exists.
  void _loadFromDisk() {
    final file = _persistFile;
    if (file == null || !file.existsSync()) return;

    try {
      final content = file.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;

      for (final entry in data.entries) {
        final value = entry.value as Map<String, dynamic>;
        final expiresAt = DateTime.parse(value['expiresAt'] as String);

        if (DateTime.now().isBefore(expiresAt)) {
          _cache[entry.key] = _CacheEntry(
            response: value['response'] as String,
            expiresAt: expiresAt,
          );
          _accessOrder.add(entry.key);
        }
      }
    } catch (e) {
      // Ignore cache load errors, start fresh
    }
  }

  /// Saves cache to disk.
  void _saveToDisk() {
    final file = _persistFile;
    if (file == null) return;

    try {
      final data = <String, dynamic>{};
      for (final entry in _cache.entries) {
        data[entry.key] = {
          'response': entry.value.response,
          'expiresAt': entry.value.expiresAt.toIso8601String(),
        };
      }

      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      file.writeAsStringSync(jsonEncode(data));
    } catch (e) {
      // Ignore cache save errors
    }
  }
}

class _CacheEntry {
  final String response;
  final DateTime expiresAt;

  _CacheEntry({required this.response, required this.expiresAt});
}
