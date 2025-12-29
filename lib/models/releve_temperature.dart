class ReleveTemperature {
  final String id;
  final String appareil;
  final double temperature;
  final DateTime date;
  final String remarque;
  final String? photoPath;

  ReleveTemperature({
    required this.id,
    required this.appareil,
    required this.temperature,
    required this.date,
    this.remarque = '',
    this.photoPath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'appareil': appareil,
        'temperature': temperature,
        'date': date.toIso8601String(),
        'remarque': remarque,
        'photo_path': photoPath,
      };

  factory ReleveTemperature.fromMap(Map<String, dynamic> map) =>
      ReleveTemperature(
        id: map['id'],
        appareil: map['appareil'],
        temperature: map['temperature'],
        date: DateTime.parse(map['date']),
        remarque: map['remarque'],
        photoPath: map['photo_path'],
      );
}
