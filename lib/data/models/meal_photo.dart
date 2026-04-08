import '../../domain/entities/meal_type.dart';

/// 饮食照片记录模型
class MealPhotoRecord {
  final String id;
  final DateTime timestamp;  // 拍照时间
  final String imagePath;  // 本地图片路径
  final int mealTypeIndex;  // 餐型索引
  final bool medicineTaken;  // 是否已吃药
  final bool medicineReminded;  // 是否已提醒
  final DateTime? medicineRemindTime;  // 提醒吃药的时间

  MealPhotoRecord({
    required this.id,
    required this.timestamp,
    required this.imagePath,
    required MealType mealType,
    this.medicineTaken = false,
    this.medicineReminded = false,
    this.medicineRemindTime,
  }) : mealTypeIndex = mealType.index;

  // 从索引获取餐型
  MealType get mealType => MealType.values[mealTypeIndex];

  // 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
      'mealTypeIndex': mealTypeIndex,
      'medicineTaken': medicineTaken,
      'medicineReminded': medicineReminded,
      'medicineRemindTime': medicineRemindTime?.toIso8601String(),
    };
  }

  // 从 JSON 创建
  factory MealPhotoRecord.fromJson(Map<String, dynamic> json) {
    return MealPhotoRecord(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      imagePath: json['imagePath'] as String,
      mealType: MealType.values[json['mealTypeIndex'] as int],
      medicineTaken: json['medicineTaken'] as bool? ?? false,
      medicineReminded: json['medicineReminded'] as bool? ?? false,
      medicineRemindTime: json['medicineRemindTime'] != null
          ? DateTime.parse(json['medicineRemindTime'] as String)
          : null,
    );
  }

  // 创建副本
  MealPhotoRecord copyWith({
    String? id,
    DateTime? timestamp,
    String? imagePath,
    MealType? mealType,
    bool? medicineTaken,
    bool? medicineReminded,
    DateTime? medicineRemindTime,
  }) {
    return MealPhotoRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      imagePath: imagePath ?? this.imagePath,
      mealType: mealType ?? this.mealType,
      medicineTaken: medicineTaken ?? this.medicineTaken,
      medicineReminded: medicineReminded ?? this.medicineReminded,
      medicineRemindTime: medicineRemindTime ?? this.medicineRemindTime,
    );
  }

  // 获取餐型显示名称
  String get mealTypeName => getMealTypeName(mealType);

  // 判断是否在目标日期
  bool isOnDate(DateTime date) {
    return timestamp.year == date.year &&
        timestamp.month == date.month &&
        timestamp.day == date.day;
  }
}
