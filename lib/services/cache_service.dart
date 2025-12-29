import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Lightweight cache service for performance (NOT offline support)
/// TTL-based cache that shows last data while loading remote
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _boxName = 'bekkapp_cache';
  Box? _box;
  bool _initialized = false;

  /// Initialize Hive and open cache box
  Future<void> initialize() async {
    if (_initialized) return;

    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    _initialized = true;
    debugPrint('[Cache] Initialized');
  }

  /// Cache data with TTL (default 10 minutes)
  Future<void> set(String key, dynamic value,
      {Duration ttl = const Duration(minutes: 10)}) async {
    if (!_initialized) await initialize();

    final expiry = DateTime.now().add(ttl);
    await _box?.put(key, {
      'value': value,
      'expiry': expiry.toIso8601String(),
    });
    debugPrint('[Cache] Set $key (expires ${expiry.toIso8601String()})');
  }

  /// Get cached data if not expired
  dynamic get(String key) {
    if (!_initialized) return null;

    final cached = _box?.get(key);
    if (cached == null) return null;

    try {
      final expiry = DateTime.parse(cached['expiry']);
      if (DateTime.now().isAfter(expiry)) {
        _box?.delete(key);
        debugPrint('[Cache] $key expired');
        return null;
      }

      debugPrint('[Cache] Hit $key');
      return cached['value'];
    } catch (e) {
      debugPrint('[Cache] Error reading $key: $e');
      _box?.delete(key);
      return null;
    }
  }

  /// Clear all cache
  Future<void> clear() async {
    if (!_initialized) return;
    await _box?.clear();
    debugPrint('[Cache] Cleared all');
  }

  /// Clear specific key
  Future<void> clearKey(String key) async {
    if (!_initialized) return;
    await _box?.delete(key);
    debugPrint('[Cache] Cleared $key');
  }

  /// Clear cache for a table/collection
  Future<void> clearTable(String tableName) async {
    if (!_initialized) return;
    final keys = _box?.keys
            .where((k) => k.toString().startsWith('${tableName}_'))
            .toList() ??
        [];
    for (final key in keys) {
      await _box?.delete(key);
    }
    debugPrint('[Cache] Cleared table $tableName (${keys.length} keys)');
  }
}
