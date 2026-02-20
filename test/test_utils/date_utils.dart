/// Test date utilities - avoid hardcoded dates, use fixed reference

/// Fixed reference date for deterministic tests
final DateTime testReferenceDate = DateTime.utc(2024, 6, 15, 12, 0);

/// Create a date relative to reference
DateTime testDate({int days = 0, int months = 0}) {
  return DateTime(
    testReferenceDate.year,
    testReferenceDate.month + months,
    testReferenceDate.day + days,
  );
}
