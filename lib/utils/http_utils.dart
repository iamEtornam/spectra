import 'dart:async';
import 'package:http/http.dart' as http;

/// Configuration for HTTP request handling.
class HttpConfig {
  /// Default timeout for HTTP requests.
  static const Duration defaultTimeout = Duration(seconds: 60);

  /// Default number of retries for failed requests.
  static const int defaultMaxRetries = 3;

  /// Default base delay between retries (exponential backoff).
  static const Duration defaultRetryDelay = Duration(seconds: 2);
}

/// Custom exception for timeout errors.
class RequestTimeoutException implements Exception {
  final String message;
  final Duration timeout;

  RequestTimeoutException({required this.message, required this.timeout});

  @override
  String toString() =>
      'RequestTimeoutException: $message (timeout: ${timeout.inSeconds}s)';
}

/// Custom exception for rate limiting.
class RateLimitException implements Exception {
  final String message;
  final Duration? retryAfter;

  RateLimitException({required this.message, this.retryAfter});

  @override
  String toString() =>
      'RateLimitException: $message${retryAfter != null ? ' (retry after: ${retryAfter!.inSeconds}s)' : ''}';
}

/// Utility class for making HTTP requests with timeout and retry logic.
class HttpUtils {
  /// Makes a POST request with timeout and retry support.
  ///
  /// [url] - The target URL.
  /// [headers] - Request headers.
  /// [body] - Request body.
  /// [timeout] - Request timeout (default: 60s).
  /// [maxRetries] - Maximum retry attempts (default: 3).
  /// [retryDelay] - Base delay between retries (default: 2s).
  static Future<http.Response> postWithRetry(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = HttpConfig.defaultTimeout,
    int maxRetries = HttpConfig.defaultMaxRetries,
    Duration retryDelay = HttpConfig.defaultRetryDelay,
  }) async {
    Exception? lastException;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(timeout, onTimeout: () {
          throw RequestTimeoutException(
            message: 'Request to $url timed out',
            timeout: timeout,
          );
        });

        // Check for rate limiting
        if (response.statusCode == 429) {
          final retryAfter = _parseRetryAfter(response.headers['retry-after']);
          throw RateLimitException(
            message: 'Rate limit exceeded',
            retryAfter: retryAfter,
          );
        }

        // Success
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        }

        // Server error - retry
        if (response.statusCode >= 500 && attempt < maxRetries) {
          await _waitWithBackoff(attempt, retryDelay);
          continue;
        }

        // Client error - don't retry
        return response;
      } on RequestTimeoutException {
        lastException = RequestTimeoutException(
          message: 'Request to $url timed out after $attempt retries',
          timeout: timeout,
        );
        if (attempt < maxRetries) {
          await _waitWithBackoff(attempt, retryDelay);
          continue;
        }
      } on RateLimitException catch (e) {
        lastException = e;
        if (attempt < maxRetries) {
          final waitDuration =
              e.retryAfter ?? _calculateBackoff(attempt, retryDelay);
          await Future<void>.delayed(waitDuration);
          continue;
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries) {
          await _waitWithBackoff(attempt, retryDelay);
          continue;
        }
      }
    }

    throw lastException ?? Exception('Unknown error during HTTP request');
  }

  /// Waits with exponential backoff.
  static Future<void> _waitWithBackoff(int attempt, Duration baseDelay) async {
    final delay = _calculateBackoff(attempt, baseDelay);
    await Future<void>.delayed(delay);
  }

  /// Calculates exponential backoff delay.
  static Duration _calculateBackoff(int attempt, Duration baseDelay) {
    // Exponential backoff: 2^attempt * baseDelay
    final multiplier = 1 << attempt; // 2^attempt
    return baseDelay * multiplier;
  }

  /// Parses the Retry-After header.
  static Duration? _parseRetryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value);
    if (seconds != null) {
      return Duration(seconds: seconds);
    }
    return null;
  }
}
