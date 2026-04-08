/// 吃药记录模型
class MedicationRecord {
  final String id;
  final String name;  // 药物名称
  final DateTime timestamp;  // 记录时间
  final bool taken;  // 是否已服用
  final String? relatedMealId;  // 关联的餐饮记录 ID
  final String? note;  // 备注

  MedicationRecord({
    required this.id,
    this.name = '降糖药',
    required this.timestamp,
    this.taken = false,
    this.relatedMealId,
    this.note,
  });

  // 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'timestamp': timestamp.toIso8601String(),
      'taken': taken,
      'relatedMealId': relatedMealId,
      'note': note,
    };
  }

  // 从 JSON 创建
  factory MedicationRecord.fromJson(Map<String, dynamic> json) {
    return MedicationRecord(
      id: json['id'] as String,
      name: json['name'] as String? ?? '降糖药',
      timestamp: DateTime.parse(json['timestamp'] as String),
      taken: json['taken'] as bool? ?? false,
      relatedMealId: json['relatedMealId'] as String?,
      note: json['note'] as String?,
    );
  }

  // 创建副本
  MedicationRecord copyWith({
    String? id,
    String? name,
    DateTime? timestamp,
    bool? taken,
    String? relatedMealId,
    String? note,
  }) {
    return MedicationRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      timestamp: timestamp ?? this.timestamp,
      taken: taken ?? this.taken,
      relatedMealId: relatedMealId ?? this.relatedMealId,
      note: note ?? this.note,
    );
  }
}
