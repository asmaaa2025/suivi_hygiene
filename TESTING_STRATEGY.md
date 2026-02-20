# HACCPilot - Testing Strategy

## Implemented Tests

| Module | Location | Status |
|--------|----------|--------|
| Text sanitization (ZPL) | `test/unit/services/text_sanitizer_service_test.dart` | ✅ |
| Temperature thresholds | `test/unit/services/temperature_threshold_test.dart` | ✅ |
| Alert engine | `test/unit/modules/alerts/alert_engine_test.dart` | ✅ |
| Alert models | `test/unit/modules/alerts/alert_models_test.dart` | ✅ |
| Compliance service | `test/compliance_service_test.dart` | ✅ |
| Temperature model | `test/unit/models/temperature_test.dart` | ✅ |
| Appareil model | `test/unit/models/appareil_test.dart` | ✅ |
| Personnel model | `test/unit/models/personnel_test.dart` | ✅ |
| EmptyState widget | `test/widget/empty_state_test.dart` | ✅ |
| SectionCard widget | `test/widget/section_card_test.dart` | ✅ |
| Integration placeholder | `integration_test/app_test.dart` | 🔄 |

## Test Structure

```
test/
├── unit/
│   ├── services/
│   │   ├── text_sanitizer_service_test.dart
│   │   └── temperature_threshold_test.dart
│   ├── modules/
│   │   └── alerts/
│   │       ├── alert_engine_test.dart
│   │       └── alert_models_test.dart
│   └── models/
│       ├── temperature_test.dart
│       ├── appareil_test.dart
│       └── personnel_test.dart
├── widget/
│   ├── empty_state_test.dart
│   └── section_card_test.dart
├── test_utils/
│   └── date_utils.dart
└── compliance_service_test.dart

integration_test/
└── app_test.dart  (placeholder)
```

## Run Tests

```bash
flutter test
flutter test --coverage
```

## CI

- **Workflow**: `.github/workflows/ci.yml`
- **Triggers**: push/PR on main, master, develop
- **Steps**: analyze, unit tests, coverage
- **Coverage**: lcov report generated

## Pending (Future Work)

- **Database tests**: NcDraftRepository, sqflite - requires in-memory/FFI setup
- **Integration tests**: Full HACCP flows - requires device/emulator
- **NC PDF export**: Mock Supabase/NCRepository
- **E2E**: `flutter drive` for full app flows
