import 'dart:io';
import 'package:flutter/foundation.dart';

/// Performance optimization utilities
class PerformanceUtils {
  /// Check if running on low-end device
  static bool isLowEndDevice() {
    if (kIsWeb) return false;
    
    // Simple heuristic based on platform
    // In production, you'd check actual device specs
    return Platform.isAndroid; // Assume Android might be low-end
  }

  /// Get recommended image quality based on device
  static int getImageQuality() {
    return isLowEndDevice() ? 70 : 90;
  }

  /// Get recommended cache size
  static int getCacheSize() {
    return isLowEndDevice() ? 50 : 100; // Number of items
  }

  /// Should use animations
  static bool shouldUseAnimations() {
    return !isLowEndDevice();
  }

  /// Get animation duration based on device
  static Duration getAnimationDuration() {
    return isLowEndDevice() 
        ? const Duration(milliseconds: 150)
        : const Duration(milliseconds: 300);
  }

  /// Optimize list rendering
  static int getListCacheExtent() {
    return isLowEndDevice() ? 50 : 100;
  }
}

/// App size analyzer
class AppSizeAnalyzer {
  /// Estimate app size categories
  static Map<String, String> getAppSizeBreakdown() {
    return {
      'Code': '~5-10 MB',
      'Assets': '~2-5 MB',
      'Dependencies': '~10-15 MB',
      'Total (Estimated)': '~20-30 MB',
    };
  }

  /// Get optimization recommendations
  static List<String> getOptimizationTips() {
    return [
      'Используйте WebP формат для изображений',
      'Удалите неиспользуемые зависимости',
      'Включите ProGuard/R8 для Android',
      'Используйте split APKs для Android',
      'Оптимизируйте размер шрифтов',
      'Удалите debug символы в release',
    ];
  }

  /// Check if app size is within target
  static bool isWithinTarget({int targetMB = 50}) {
    // In production, check actual app size
    const estimatedSize = 25; // MB
    return estimatedSize <= targetMB;
  }
}

/// Memory optimization utilities
class MemoryOptimizer {
  static final Map<String, dynamic> _cache = {};
  static const int _maxCacheSize = 100;

  /// Add item to cache
  static void cache(String key, dynamic value) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest item (simple FIFO)
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  /// Get item from cache
  static T? getCached<T>(String key) {
    return _cache[key] as T?;
  }

  /// Clear cache
  static void clearCache() {
    _cache.clear();
  }

  /// Get cache size
  static int getCacheSize() {
    return _cache.length;
  }

  /// Get memory usage estimate
  static String getMemoryUsage() {
    final cacheSize = _cache.length;
    final estimatedMB = (cacheSize * 0.1).toStringAsFixed(2);
    return '$estimatedMB MB';
  }
}
