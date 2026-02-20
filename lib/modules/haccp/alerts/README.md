# HACCP Alert System Implementation

## Overview

This is a unified HACCP alert system for "100% Crousty Sevran" that evaluates events from 4 modules (temperature, reception, oil, cleaning) and generates normalized alerts based on JSON-driven rules.

## Architecture

### Components

1. **Models** (`models.dart`)
   - `Alert`: Main alert model
   - `AlertEvent`: Event that triggers evaluation
   - `AlertRule`: Rule definition from JSON
   - `AlertType`: Alert metadata from JSON
   - Enums: `AlertSeverity`, `AlertStatus`

2. **Alert Engine** (`alert_engine.dart`)
   - Loads rules from JSON
   - Evaluates events against rules
   - Normalizes event payloads
   - Generates alerts

3. **Alert Repository** (`alert_repository.dart`)
   - Stores alerts in Supabase
   - Handles deduplication
   - Provides query methods

4. **Alert Service** (`alert_service.dart`)
   - High-level API for modules
   - Initializes engine
   - Coordinates evaluation and storage

## Database Schema

Run `25_create_haccp_alerts_table.sql` in Supabase to create the alerts table.

## Integration Points

### Temperature Module
✅ **COMPLETED** - Integrated in `lib/data/repositories/temperature_repository.dart`
- Calls `_evaluateTemperatureAlerts()` after creating a temperature reading
- Passes device info, thresholds, and temperature value

### Reception Module
⏳ **TODO** - Add integration in `lib/data/repositories/reception_repository.dart`
- After creating/updating a reception, create event:
  ```dart
  final event = AlertEvent(
    eventType: 'reception.checked',
    payload: {
      'product_id': reception.produitId,
      'product_name': productName,
      'supplier_id': reception.supplierId,
      'temperature': reception.temperature,
      'packaging': {
        'issue': packagingIssue, // 'wet_carton', 'broken_seal', etc.
      },
      'label': {
        'missing_fields': missingFields,
        'missing_fields_count': missingFields.length,
      },
      'lot': reception.lot,
    },
    organizationId: orgId,
    employeeId: employeeId,
  );
  await AlertService.instance.evaluateAndStore(event);
  ```

### Oil Module
⏳ **TODO** - Add integration in `lib/repositories/oil_change_repository.dart`
- After logging oil check or change:
  ```dart
  final event = AlertEvent(
    eventType: 'oil.check_logged', // or 'oil.change_logged'
    payload: {
      'fryer_id': fryerId,
      'fryer_name': fryerName,
      'oil_state': oilState, // 'ok', 'dark', 'foamy', etc.
      'days_since_change': daysSinceChange,
      'cycles': cycles,
    },
    organizationId: orgId,
    employeeId: employeeId,
  );
  await AlertService.instance.evaluateAndStore(event);
  ```

### Cleaning Module
⏳ **TODO** - Add integration in cleaning task completion logic
- When closing a day or marking tasks:
  ```dart
  final event = AlertEvent(
    eventType: 'cleaning.day_closed',
    payload: {
      'missed_count': missedTasksCount,
      'date': date,
    },
    organizationId: orgId,
    employeeId: employeeId,
  );
  await AlertService.instance.evaluateAndStore(event);
  ```

## UI Components

⏳ **TODO** - Create Alerts Inbox UI:
- `lib/features/haccp/pages/alerts_inbox_page.dart`
- List view with filters (severity, module, status)
- Alert detail view with actions
- "Mark as resolved" button
- "Create corrective action" button

## Initialization

Add to `main.dart` or app initialization:

```dart
// Initialize alert service
await AlertService.instance.initialize();
```

## Testing

⏳ **TODO** - Create unit tests:
- `test/modules/haccp/alerts/alert_engine_test.dart`
- Test rule evaluation
- Test edge cases (nulls, boundaries)
- Test multiple rules triggered
- Test day rollovers

## Usage Example

```dart
// In any module after creating/updating a record:
final alertService = AlertService.instance;
await alertService.initialize();

final event = AlertEvent(
  eventType: 'temperature.logged',
  payload: {
    'temperature_c': 8.5,
    'device_id': 'device-123',
    'device_name': 'Frigo 1',
    'device_temp_min': 0.0,
    'device_temp_max': 4.0,
  },
  organizationId: orgId,
  employeeId: employeeId,
);

final alerts = await alertService.evaluateAndStore(event);
// Alerts are automatically stored and deduplicated
```

## Next Steps

1. ✅ Models created
2. ✅ Engine created
3. ✅ Repository created
4. ✅ Service created
5. ✅ Temperature integration completed
6. ⏳ Reception integration
7. ⏳ Oil integration
8. ⏳ Cleaning integration
9. ⏳ UI components
10. ⏳ Unit tests











