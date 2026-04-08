import 'dart:io';
import '../models/meal_photo.dart';
import '../local/hive_service.dart';
import '../../domain/entities/meal_type.dart';

/// 饮食照片数据仓库
class MealPhotoRepository {
  /// 获取所有饮食记录
  List<MealPhotoRecord> getAll() {
    return HiveService.allMealRecords
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// 获取今日饮食记录
  List<MealPhotoRecord> getTodayRecords() {
    final now = DateTime.now();
    return getByDate(now);
  }

  /// 获取指定日期的饮食记录
  List<MealPhotoRecord> getByDate(DateTime date) {
    return HiveService.getMealRecordsByDate(_normalizeDate(date))
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// 添加饮食记录
  Future<MealPhotoRecord> add({
    required String imagePath,
    required MealType mealType,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final record = MealPhotoRecord(
      id: now.millisecondsSinceEpoch.toString(),
      timestamp: now,
      imagePath: imagePath,
      mealType: mealType,
      medicineReminded: true,
      medicineRemindTime: now.add(const Duration(minutes: 30)),
    );
    await HiveService.addMealRecord(record);
    return record;
  }

  /// 更新饮食记录
  Future<void> update(MealPhotoRecord record) async {
    await HiveService.updateMealRecord(record);
  }

  /// 删除饮食记录
  Future<void> delete(String id) async {
    final records = getAll();
    final record = records.where((r) => r.id == id).firstOrNull;
    if (record != null) {
      // 删除关联的图片文件
      final file = File(record.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await HiveService.deleteMealRecord(id);
  }

  /// 标记已吃药
  Future<void> markMedicineTaken(String id) async {
    final records = getAll();
    final record = records.where((r) => r.id == id).firstOrNull;
    if (record != null) {
      await update(record.copyWith(
        medicineTaken: true,
        medicineReminded: true,
      ));
    }
  }

  /// 获取需要提醒吃药的记录
  List<MealPhotoRecord> getMedicineReminders() {
    final now = DateTime.now();
    return getAll().where((record) {
      // 已吃药的不需要提醒
      if (record.medicineTaken) return false;

      // 检查是否到了提醒时间（饭后 30 分钟）
      if (record.medicineRemindTime != null) {
        return now.isAfter(record.medicineRemindTime!);
      }

      // 首次检查：饭后 30 分钟提醒
      final remindTime = record.timestamp.add(const Duration(minutes: 30));
      return now.isAfter(remindTime);
    }).toList();
  }

  /// 设置提醒时间
  Future<void> setRemindTime(String id, DateTime remindTime) async {
    final records = getAll();
    final record = records.where((r) => r.id == id).firstOrNull;
    if (record != null) {
      await update(record.copyWith(
        medicineReminded: true,
        medicineRemindTime: remindTime,
      ));
    }
  }

  /// 标准化日期
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
