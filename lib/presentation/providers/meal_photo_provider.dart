import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../data/models/meal_photo.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/cloud_api_service.dart';
import '../../data/remote/cloud_sync_service.dart';
import '../../domain/entities/meal_type.dart';

/// 饮食照片状态
class MealPhotoState {
  final List<MealPhotoRecord> records;
  final List<MealPhotoRecord> todayRecords;
  final List<MealPhotoRecord> medicineReminders;
  final bool isLoading;
  final String? error;

  MealPhotoState({
    this.records = const [],
    this.todayRecords = const [],
    this.medicineReminders = const [],
    this.isLoading = false,
    this.error,
  });

  MealPhotoState copyWith({
    List<MealPhotoRecord>? records,
    List<MealPhotoRecord>? todayRecords,
    List<MealPhotoRecord>? medicineReminders,
    bool? isLoading,
    String? error,
  }) {
    return MealPhotoState(
      records: records ?? this.records,
      todayRecords: todayRecords ?? this.todayRecords,
      medicineReminders: medicineReminders ?? this.medicineReminders,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// 饮食照片 Provider
final mealPhotoProvider = StateNotifierProvider<MealPhotoNotifier, MealPhotoState>((ref) {
  return MealPhotoNotifier();
});

class MealPhotoNotifier extends StateNotifier<MealPhotoState> {
  final CloudApiService _api = CloudApiService();
  final CloudSyncService _syncService = CloudSyncService();
  final ImagePicker _picker = ImagePicker();

  MealPhotoNotifier() : super(MealPhotoState()) {
    // 监听同步服务的数据变化
    _syncService.onDataChanged = _onDataChanged;
    loadAll();
  }

  /// 数据变化通知（来自同步服务）
  void _onDataChanged() {
    print('[MealPhotoProvider] 数据已变更，刷新状态');
    loadAll();
  }

  /// 加载所有数据（从本地缓存读取）
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 从本地 Hive 读取数据（服务器数据已同步到本地）
      final allRecords = _getAllFromLocal();
      final todayRecords = _getTodayFromLocal();
      final medicineReminders = _getMedicineRemindersFromLocal();

      state = state.copyWith(
        records: allRecords,
        todayRecords: todayRecords,
        medicineReminders: medicineReminders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 从本地获取所有记录
  List<MealPhotoRecord> _getAllFromLocal() {
    return HiveService.allMealRecords
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// 从本地获取今日记录
  List<MealPhotoRecord> _getTodayFromLocal() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _getAllFromLocal()
      ..where((r) => r.timestamp.isAfter(today.subtract(const Duration(days: 1))))
      .toList();
  }

  /// 从本地获取需要提醒的记录
  List<MealPhotoRecord> _getMedicineRemindersFromLocal() {
    final now = DateTime.now();
    return _getAllFromLocal().where((record) {
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

  /// 拍照并添加记录（先保存本地，然后异步上传到服务器）
  Future<MealPhotoRecord?> takePhoto(MealType mealType) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo == null) return null;

      // 保存图片到本地存储目录
      final storageDir = await HiveService.getImageStorageDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${mealType.name}_$timestamp.jpg';
      final savedPath = '$storageDir/$fileName';

      // 复制文件到存储目录
      final file = File(photo.path);
      await file.copy(savedPath);

      // 等待文件写入完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证文件存在
      if (!await File(savedPath).exists()) {
        throw Exception('图片文件保存失败：$savedPath');
      }

      // 创建记录
      final now = DateTime.now();
      final record = MealPhotoRecord(
        id: now.millisecondsSinceEpoch.toString(),
        timestamp: now,
        imagePath: savedPath,
        mealType: mealType,
        medicineReminded: true,
        medicineRemindTime: now.add(const Duration(minutes: 30)),
      );

      // 保存到本地
      await HiveService.addMealRecord(record);

      // 上传到服务器（异步）
      _uploadToCloud(record);

      await loadAll();
      return record;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      print('拍照失败：$e');
      return null;
    }
  }

  /// 从相册选择照片
  Future<MealPhotoRecord?> pickFromGallery(MealType mealType) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (photo == null) return null;

      // 保存图片到本地存储目录
      final storageDir = await HiveService.getImageStorageDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${mealType.name}_$timestamp.jpg';
      final savedPath = '$storageDir/$fileName';

      // 复制文件到存储目录
      final file = File(photo.path);
      await file.copy(savedPath);

      // 等待文件写入完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 验证文件存在
      if (!await File(savedPath).exists()) {
        throw Exception('图片文件保存失败：$savedPath');
      }

      // 创建记录
      final now = DateTime.now();
      final record = MealPhotoRecord(
        id: now.millisecondsSinceEpoch.toString(),
        timestamp: now,
        imagePath: savedPath,
        mealType: mealType,
        medicineReminded: true,
        medicineRemindTime: now.add(const Duration(minutes: 30)),
      );

      // 保存到本地
      await HiveService.addMealRecord(record);

      // 上传到服务器（异步）
      _uploadToCloud(record);

      await loadAll();
      return record;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      print('选择照片失败：$e');
      return null;
    }
  }

  /// 上传单条记录到服务器（后台任务）
  Future<void> _uploadToCloud(MealPhotoRecord record) async {
    try {
      print('开始上传饮食记录：${record.id}, 图片路径：${record.imagePath}');

      // 验证文件存在
      if (!await File(record.imagePath).exists()) {
        print('图片文件不存在：${record.imagePath}');
        throw Exception('图片文件不存在：${record.imagePath}');
      }

      await _api.uploadMealRecord(record);
      print('饮食记录已上传到服务器：${record.id}');
    } catch (e) {
      // 上传失败不阻塞 UI，记录日志
      print('上传饮食记录失败：$e');
    }
  }

  /// 删除记录（同时删除本地和云端）
  Future<void> deleteRecord(String id) async {
    try {
      // 1. 先删除本地数据
      await HiveService.deleteMealRecord(id);

      // 2. 异步删除云端数据
      _deleteFromCloud(id);

      await loadAll();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 从云端删除记录（后台任务）
  Future<void> _deleteFromCloud(String id) async {
    try {
      await _api.deleteMealRecord(id);
      print('饮食记录已从云端删除：$id');
    } catch (e) {
      // 删除失败不阻塞 UI，记录日志
      print('删除云端饮食记录失败：$e');
    }
  }

  /// 标记已吃药
  Future<void> markMedicineTaken(String id) async {
    try {
      final records = _getAllFromLocal();
      final record = records.where((r) => r.id == id).firstOrNull;
      if (record != null) {
        final updatedRecord = record.copyWith(
          medicineTaken: true,
          medicineReminded: true,
        );
        await HiveService.updateMealRecord(updatedRecord);
        await loadAll();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 刷新提醒
  Future<void> refreshReminders() async {
    final medicineReminders = _getMedicineRemindersFromLocal();
    state = state.copyWith(medicineReminders: medicineReminders);
  }
}
