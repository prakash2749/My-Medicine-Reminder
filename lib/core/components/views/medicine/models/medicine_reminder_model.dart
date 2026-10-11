class MedicineReminder {
  final String id;
  final String name;
  final String dosage;
  final String time;
  final String frequency;
  final String category;
  final String? notes;
  final bool isTaken;
  final DateTime createdAt;

  const MedicineReminder({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    this.frequency = 'Daily',
    this.category = 'Pill',
    this.notes,
    this.isTaken = false,
    required this.createdAt,
  });

  MedicineReminder copyWith({
    String? id,
    String? name,
    String? dosage,
    String? time,
    String? frequency,
    String? category,
    String? notes,
    bool? isTaken,
    DateTime? createdAt,
  }) {
    return MedicineReminder(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      time: time ?? this.time,
      frequency: frequency ?? this.frequency,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isTaken: isTaken ?? this.isTaken,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'time': time,
      'frequency': frequency,
      'category': category,
      'notes': notes,
      'is_taken': isTaken,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MedicineReminder.fromJson(Map<String, dynamic> json) {
    return MedicineReminder(
      id: json['id'] as String,
      name: json['name'] as String,
      dosage: json['dosage'] as String? ?? '',
      time: json['time'] as String? ?? '08:00 AM',
      frequency: json['frequency'] as String? ?? 'Daily',
      category: json['category'] as String? ?? 'Pill',
      notes: json['notes'] as String?,
      isTaken: json['is_taken'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
