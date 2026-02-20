/// Unit tests for temperature threshold logic (HACCP chaine du froid)

import 'package:flutter_test/flutter_test.dart';

/// Pure functions for temperature threshold validation - testable business logic
class TemperatureThresholdHelper {
  /// Check if temperature is within device range
  static bool isWithinRange(double temp, double? min, double? max) {
    if (min == null && max == null) return true;
    if (min != null && temp < min) return false;
    if (max != null && temp > max) return false;
    return true;
  }

  /// Default fridge range (0-4°C) when device has no thresholds
  static const double defaultFridgeMin = 0.0;
  static const double defaultFridgeMax = 4.0;

  /// Default freezer range (-25 to -18°C)
  static const double defaultFreezerMin = -25.0;
  static const double defaultFreezerMax = -18.0;

  /// Check if value is valid (not NaN, not infinite)
  static bool isValidValue(double? temp) {
    if (temp == null) return false;
    return !temp.isNaN && !temp.isInfinite;
  }

  /// Severity of out-of-range: warn vs critical (beyond margin)
  static String getOutOfRangeSeverity(
    double temp,
    double min,
    double max, {
    double criticalMargin = 2.0,
  }) {
    if (temp >= min && temp <= max) return 'ok';
    if (temp < min - criticalMargin || temp > max + criticalMargin) {
      return 'critical';
    }
    return 'warn';
  }
}

void main() {
  group('TemperatureThresholdHelper', () {
    group('isWithinRange', () {
      test('returns true when temp within min and max', () {
        expect(
          TemperatureThresholdHelper.isWithinRange(3.0, 2.0, 4.0),
          true,
        );
      });

      test('returns false when temp below min', () {
        expect(
          TemperatureThresholdHelper.isWithinRange(1.0, 2.0, 4.0),
          false,
        );
      });

      test('returns false when temp above max', () {
        expect(
          TemperatureThresholdHelper.isWithinRange(6.0, 2.0, 4.0),
          false,
        );
      });

      test('returns true when min and max are null', () {
        expect(
          TemperatureThresholdHelper.isWithinRange(100.0, null, null),
          true,
        );
      });

      test('boundary: temp equals min is in range', () {
        expect(
          TemperatureThresholdHelper.isWithinRange(2.0, 2.0, 4.0),
          true,
        );
      });

      test('boundary: temp equals max is in range', () {
        expect(
          TemperatureThresholdHelper.isWithinRange(4.0, 2.0, 4.0),
          true,
        );
      });
    });

    group('isValidValue', () {
      test('returns false for null', () {
        expect(TemperatureThresholdHelper.isValidValue(null), false);
      });

      test('returns false for NaN', () {
        expect(TemperatureThresholdHelper.isValidValue(double.nan), false);
      });

      test('returns false for infinite', () {
        expect(TemperatureThresholdHelper.isValidValue(double.infinity), false);
      });

      test('returns true for valid number', () {
        expect(TemperatureThresholdHelper.isValidValue(3.5), true);
      });
    });

    group('getOutOfRangeSeverity', () {
      test('returns ok when in range', () {
        expect(
          TemperatureThresholdHelper.getOutOfRangeSeverity(3.0, 2.0, 4.0),
          'ok',
        );
      });

      test('returns warn when slightly out of range', () {
        expect(
          TemperatureThresholdHelper.getOutOfRangeSeverity(5.0, 2.0, 4.0),
          'warn',
        );
      });

      test('returns critical when beyond margin', () {
        expect(
          TemperatureThresholdHelper.getOutOfRangeSeverity(10.0, 2.0, 4.0),
          'critical',
        );
      });

      test('returns critical when below min - margin', () {
        expect(
          TemperatureThresholdHelper.getOutOfRangeSeverity(-5.0, 2.0, 4.0),
          'critical',
        );
      });
    });
  });
}
