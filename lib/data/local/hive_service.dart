import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/blood_glucose.dart';
import '../models/meal_photo.dart';

/// Hive 本地存储服务
class HiveService {
  static const String glucoseBoxName = 'blood_glucose';
  static const String mealBoxName = 'meal_photos';
  static const String medicationBoxName = 'medications';
  static const String settingsBoxName = 'settings';

  static late Box _glucoseBox;
  static late Box _mealBox;
  static late Box _medicationBox;
  static late Box _settingsBox;

  /// 初始化 Hive
  static Future<void> init() async {
    await Hive.initFlutter();

    // 获取应用文档目录
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);

    // 打开各个数据盒
    _glucoseBox = await Hive.openBox(glucoseBoxName);
    _mealBox = await Hive.openBox(mealBoxName);
    _medicationBox = await Hive.openBox(medicationBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);
  }

  // ==================== 血糖数据操作 ====================

  /// 获取所有血糖记录
  static List<BloodGlucoseRecord> get allGlucoseRecords {
    return _glucoseBox.values.map((e) {
      if (e is BloodGlucoseRecord) return e;
      if (e is Map) return BloodGlucoseRecord.fromJson(Map<String, dynamic>.from(e));
      throw Exception('Unknown data type in Hive box');
    }).toList();
  }

  /// 获取指定日期的血糖记录
  static List<BloodGlucoseRecord> getGlucoseRecordsByDate(DateTime date) {
    return allGlucoseRecords.where((record) {
      return record.timestamp.year == date.year &&
          record.timestamp.month == date.month &&
          record.timestamp.day == date.day;
    }).toList();
  }

  /// 获取指定日期范围的血糖记录
  static List<BloodGlucoseRecord> getGlucoseRecordsByRange(DateTime start, DateTime end) {
    return allGlucoseRecords.where((record) {
      return record.timestamp.isAfter(start.subtract(const Duration(days: 1))) &&
          record.timestamp.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  /// 添加血糖记录 - 保存为 Map
  static Future<void> addGlucoseRecord(BloodGlucoseRecord record) async {
    await _glucoseBox.put(record.id, record.toJson());
  }

  /// 更新血糖记录
  static Future<void> updateGlucoseRecord(BloodGlucoseRecord record) async {
    await _glucoseBox.put(record.id, record.toJson());
  }

  /// 删除血糖记录
  static Future<void> deleteGlucoseRecord(String id) async {
    await _glucoseBox.delete(id);
  }

  /// 清空所有血糖记录
  static Future<void> clearAllGlucoseRecords() async {
    await _glucoseBox.clear();
  }

  /// 清空所有饮食记录
  static Future<void> clearAllMealRecords() async {
    await _mealBox.clear();
  }

  /// 清空所有吃药记录
  static Future<void> clearAllMedicationRecords() async {
    await _medicationBox.clear();
  }

  // ==================== 饮食照片数据操作 ====================

  /// 获取所有饮食记录
  static List<MealPhotoRecord> get allMealRecords {
    return _mealBox.values.map((e) {
      if (e is MealPhotoRecord) return e;
      if (e is Map) return MealPhotoRecord.fromJson(Map<String, dynamic>.from(e));
      throw Exception('Unknown data type in Hive box');
    }).toList();
  }

  /// 获取指定日期的饮食记录
  static List<MealPhotoRecord> getMealRecordsByDate(DateTime date) {
    return allMealRecords.where((record) {
      return record.timestamp.year == date.year &&
          record.timestamp.month == date.month &&
          record.timestamp.day == date.day;
    }).toList();
  }

  /// 添加饮食记录 - 保存为 Map
  static Future<void> addMealRecord(MealPhotoRecord record) async {
    await _mealBox.put(record.id, record.toJson());
  }

  /// 更新饮食记录
  static Future<void> updateMealRecord(MealPhotoRecord record) async {
    await _mealBox.put(record.id, record.toJson());
  }

  /// 删除饮食记录
  static Future<void> deleteMealRecord(String id) async {
    await _mealBox.delete(id);
  }

  // ==================== 吃药记录数据操作 ====================

  /// 获取所有吃药记录
  static List get allMedicationRecords => _medicationBox.values.toList();

  /// 获取指定日期的吃药记录
  static List getMedicationRecordsByDate(DateTime date) {
    return _medicationBox.values.where((record) {
      return record.timestamp.year == date.year &&
          record.timestamp.month == date.month &&
          record.timestamp.day == date.day;
    }).toList();
  }

  /// 添加吃药记录
  static Future<void> addMedicationRecord(dynamic record) async {
    await _medicationBox.put(record.id, record);
  }

  /// 更新吃药记录
  static Future<void> updateMedicationRecord(dynamic record) async {
    await _medicationBox.put(record.id, record);
  }

  /// 删除吃药记录
  static Future<void> deleteMedicationRecord(String id) async {
    await _medicationBox.delete(id);
  }

  // ==================== 设置数据操作 ====================

  /// 获取设置值
  static T getValue<T>(String key, T defaultValue) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T;
  }

  /// 设置值
  static Future<void> setValue<T>(String key, T value) async {
    await _settingsBox.put(key, value);
  }

  /// 获取所有血糖记录 ID
  static List<String> get allGlucoseIds {
    return _glucoseBox.keys.map((k) => k.toString()).toList();
  }

  /// 获取所有饮食记录 ID
  static List<String> get allMealIds {
    return _mealBox.keys.map((k) => k.toString()).toList();
  }

  /// 获取所有记录 ID（血糖 + 饮食）
  static List<String> get allRecordIds {
    return [...allGlucoseIds, ...allMealIds];
  }

  /// 获取图片存储目录
  static Future<String> getImageStorageDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${dir.path}/images');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir.path;
  }

  /// 关闭 Hive
  static Future<void> close() async {
    await _glucoseBox.close();
    await _mealBox.close();
    await _medicationBox.close();
    await _settingsBox.close();
  }
}
