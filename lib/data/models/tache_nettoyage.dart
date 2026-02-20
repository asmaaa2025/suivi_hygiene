/// Cleaning task with recurrence model
class TacheNettoyage {
  final String id;
  final String nom;
  final String recurrenceType; // 'daily', 'weekly', 'monthly'
  final int interval; // e.g., every 1 week, every 2 weeks
  final List<int>? weekdays; // 1-7 (Mon-Sun), only for weekly
  final int? dayOfMonth; // 1-31, only for monthly
  final String timeOfDay; // "HH:mm" format
  final bool isActive;
  final DateTime createdAt;

  TacheNettoyage({
    required this.id,
    required this.nom,
    required this.recurrenceType,
    required this.interval,
    this.weekdays,
    this.dayOfMonth,
    required this.timeOfDay,
    this.isActive = true,
    required this.createdAt,
  });

  factory TacheNettoyage.fromJson(Map<String, dynamic> json) {
    return TacheNettoyage(
      id: (json['id'] as String?) ?? '',
      nom: (json['nom'] as String?) ?? '',
      recurrenceType: (json['recurrence_type'] as String?) ?? 'daily',
      interval: (json['interval'] as int?) ?? 1,
      weekdays: json['weekdays'] != null
          ? (json['weekdays'] is List
                ? List<int>.from(
                    (json['weekdays'] as List).map(
                      (e) => (e as num?)?.toInt() ?? 0,
                    ),
                  )
                : null)
          : null,
      dayOfMonth: (json['day_of_month'] as int?),
      timeOfDay: (json['time_of_day'] as String?) ?? '08:00',
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'recurrence_type': recurrenceType,
      'interval': interval,
      'weekdays': weekdays,
      'day_of_month': dayOfMonth,
      'time_of_day': timeOfDay,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
