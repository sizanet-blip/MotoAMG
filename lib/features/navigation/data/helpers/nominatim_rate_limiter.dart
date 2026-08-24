import 'dart:async';

/// Respeta el límite de Nominatim público (~1 petición por segundo).
final class NominatimRateLimiter {
  NominatimRateLimiter._();

  static final NominatimRateLimiter instance = NominatimRateLimiter._();

  DateTime? _lastRequestAt;
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      final wait = _waitDuration();
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
      _lastRequestAt = DateTime.now();
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Duration _waitDuration() {
    final last = _lastRequestAt;
    if (last == null) {
      return Duration.zero;
    }
    const minInterval = Duration(milliseconds: 1100);
    final elapsed = DateTime.now().difference(last);
    return elapsed >= minInterval ? Duration.zero : minInterval - elapsed;
  }
}
