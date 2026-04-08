import '../../domain/entities/time_period.dart';

/// 血糖记录模型
class BloodGlucoseRecord {
  final String id;
  final double value;  // 血糖值 (mmol/L)
  final DateTime timestamp;  // 测量时间
  final int periodIndex;  // 时段索引
  final String? note;  // 备注
  final bool isPostMeal;  // 是否餐后

  BloodGlucoseRecord({
    required this.id,
    required this.value,
    required this.timestamp,
    required TimePeriod period,
    this.note,
    this.isPostMeal = false,
  }) : periodIndex = period.index;

  // 从索引获取时段
  TimePeriod get period => TimePeriod.values[periodIndex];

  // 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'periodIndex': periodIndex,
      'note': note,
      'isPostMeal': isPostMeal,
    };
  }

  // 从 JSON 创建
  factory BloodGlucoseRecord.fromJson(Map<String, dynamic> json) {
    return BloodGlucoseRecord(
      id: json['id'] as String,
      value: (json['value'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      period: TimePeriod.values[json['periodIndex'] as int],
      note: json['note'] as String?,
      isPostMeal: json['isPostMeal'] as bool? ?? false,
    );
  }

  // 创建副本
  BloodGlucoseRecord copyWith({
    String? id,
    double? value,
    DateTime? timestamp,
    TimePeriod? period,
    String? note,
    bool? isPostMeal,
  }) {
    return BloodGlucoseRecord(
      id: id ?? this.id,
      value: value ?? this.value,
      timestamp: timestamp ?? this.timestamp,
      period: period ?? this.period,
      note: note ?? this.note,
      isPostMeal: isPostMeal ?? this.isPostMeal,
    );
  }

  // 判断是否在目标日期
  bool isOnDate(DateTime date) {
    return timestamp.year == date.year &&
        timestamp.month == date.month &&
        timestamp.day == date.day;
  }

  // 判断是否在某天
  bool isSameDay(DateTime other) {
    return timestamp.year == other.year &&
        timestamp.month == other.month &&
        timestamp.day == other.day;
  }
}
