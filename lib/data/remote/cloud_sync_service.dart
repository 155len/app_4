import '../models/blood_glucose.dart';
import '../models/meal_photo.dart';
import '../local/hive_service.dart';
import '../remote/cloud_api_service.dart';
import '../remote/image_download_service.dart';
import '../../config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// 云同步服务
/// 负责本地数据与云端数据的双向同步
///
/// 同步策略：
/// 1. 服务器为唯一数据源，本地 Hive 仅作为缓存
/// 2. 删除操作会同步到服务器，服务器记录已删除 ID
/// 3. 同步时不会重新拉取已删除的数据
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final CloudApiService _api = CloudApiService();
  final Uuid _uuid = const Uuid();

  /// 设备 ID
  String? _deviceId;

  /// 同步状态回调
  Function(String status)? onStatusUpdate;
  Function(int progress)? onProgressUpdate;
  /// 数据变化回调（用于通知 Provider 刷新）
  VoidCallback? onDataChanged;

  /// 是否正在同步
  bool _isSyncing = false;

  /// 上次同步时间（服务器时间）
  DateTime? _lastSyncTime;

  /// 本地时间偏移（用于时间校准）
  Duration? _timeOffset;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  Duration? get timeOffset => _timeOffset;
  String get deviceId {
    if (_deviceId == null || _deviceId!.isEmpty) {
      var id = HiveService.getValue('device_id', '');
      if (id.isEmpty) {
        id = _uuid.v4();
        HiveService.setValue('device_id', id);
      }
      _deviceId = id;
    }
    return _deviceId!;
  }

  /// 初始化设备 ID
  Future<void> _initDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) return;

    var id = HiveService.getValue('device_id', '');
    if (id.isEmpty) {
      id = _uuid.v4();
      await HiveService.setValue('device_id', id);
    }
    _deviceId = id;
  }

  /// 检查网络连接
  Future<bool> checkConnection() async {
    return await _api.checkConnection();
  }

  /// 校准时间（获取服务器时间并计算偏移）
  Future<DateTime?> calibrateTime() async {
    try {
      final serverTime = await _api.getServerTime();
      _timeOffset = _api.timeOffset;
      _notifyStatus('时间校准完成');
      return serverTime;
    } catch (e) {
      _notifyStatus('时间校准失败：$e');
      return null;
    }
  }

  /// 获取校准后的时间（本地时间 + 偏移量）
  DateTime getCalibratedTime() {
    if (_timeOffset != null) {
      return DateTime.now().add(_timeOffset!);
    }
    return DateTime.now();
  }

  /// 全量同步 - 从服务器获取所有数据
  Future<void> fullSync() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      await _initDeviceId();
      _notifyStatus('开始全量同步...');

      // 1. 先校准时间
      await calibrateTime();

      // 2. 上传本地数据到云端
      await _uploadLocalData();

      // 3. 从云端下载所有数据（覆盖本地）
      await _downloadAllRemoteData();

      _lastSyncTime = _api.serverTime ?? DateTime.now();
      _notifyStatus('全量同步完成');
      _notifyDataChanged();
    } catch (e) {
      _notifyStatus('全量同步失败：$e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// 增量同步 - 同步服务器所有数据到本地
  Future<void> incrementalSync({bool force = false}) async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      await _initDeviceId();
      _notifyStatus('开始同步...');

      // 1. 校准时间
      await calibrateTime();

      // 2. 上传本地新增/修改的数据
      await _uploadLocalData();

      // 3. 从服务器获取所有数据，更新本地缓存
      await _syncAllRemoteData();

      _lastSyncTime = _api.serverTime ?? DateTime.now();
      _notifyStatus('同步完成');
      _notifyDataChanged();
    } catch (e) {
      _notifyStatus('同步失败：$e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// 上传本地数据到服务器
  Future<void> _uploadLocalData() async {
    _notifyStatus('正在上传本地数据...');

    // 上传血糖记录
    final glucoseRecords = HiveService.allGlucoseRecords;
    int uploaded = 0;
    for (final record in glucoseRecords) {
      try {
        await _api.uploadGlucoseRecord(record);
        uploaded++;
        _notifyProgress((uploaded / (glucoseRecords.length + 1) * 50).toInt());
      } catch (e) {
        print('上传血糖记录失败：$e');
      }
    }
    _notifyStatus('已上传 $uploaded 条血糖记录');

    // 上传饮食记录
    final mealRecords = HiveService.allMealRecords;
    uploaded = 0;
    for (final record in mealRecords) {
      try {
        await _api.uploadMealRecord(record);
        uploaded++;
        _notifyProgress(50 + (uploaded / (mealRecords.length + 1) * 50).toInt());
      } catch (e) {
        print('上传饮食记录失败：$e');
      }
    }
    _notifyStatus('已上传 $uploaded 条饮食记录');
  }

  /// 从云端下载所有数据（覆盖本地缓存）
  Future<void> _downloadAllRemoteData() async {
    _notifyStatus('正在下载云端所有数据...');

    try {
      // 下载所有血糖记录
      final remoteGlucose = await _api.getGlucoseRecords();
      await _replaceGlucoseRecords(remoteGlucose);
      _notifyStatus('已同步 ${remoteGlucose.length} 条血糖记录');

      // 下载所有饮食记录
      final remoteMeals = await _api.getMealRecords();
      await _replaceMealRecords(remoteMeals);
      _notifyStatus('已同步 ${remoteMeals.length} 条饮食记录');

      // 下载所有图片
      await _downloadAllImages();

      _notifyStatus('全量同步完成');
    } catch (e) {
      print('下载云端数据失败：$e');
      rethrow;
    }
  }

  /// 从服务器同步所有数据（替换本地缓存）
  Future<void> _syncAllRemoteData() async {
    _notifyStatus('正在同步云端数据...');

    try {
      // 获取服务器所有数据
      final result = await _api.incrementalSync(
        lastSyncTime: null,
        deviceIds: null,
      );

      // 替换血糖记录
      await _replaceGlucoseRecords(result.glucoseRecords);
      _notifyStatus('已同步 ${result.glucoseRecords.length} 条血糖记录');

      // 替换饮食记录
      await _replaceMealRecords(result.mealRecords);
      _notifyStatus('已同步 ${result.mealRecords.length} 条饮食记录');
    } catch (e) {
      print('同步云端数据失败：$e');
      rethrow;
    }
  }

  /// 替换血糖记录（完全覆盖本地）
  Future<void> _replaceGlucoseRecords(List<BloodGlucoseRecord> remoteRecords) async {
    // 清空本地血糖记录
    await HiveService.clearAllGlucoseRecords();

    // 保存所有服务器数据
    for (final record in remoteRecords) {
      await HiveService.addGlucoseRecord(record);
    }
  }

  /// 替换饮食记录（完全覆盖本地）
  Future<void> _replaceMealRecords(List<MealPhotoRecord> remoteRecords) async {
    // 清空本地饮食记录
    await HiveService.clearAllMealRecords();

    // 保存所有服务器数据
    for (final record in remoteRecords) {
      await HiveService.addMealRecord(record);
    }
  }

  /// 后台下载图片
  Future<void> _downloadImagesInBackground(List<MealPhotoRecord> records) async {
    try {
      _notifyStatus('正在下载 ${records.length} 张图片...');

      int downloaded = 0;
      for (final record in records) {
        try {
          if (await ImageDownloadService.isImageCached(record.id)) {
            continue;
          }
          await ImageDownloadService.downloadImage(record.id, record.imagePath);
          downloaded++;
        } catch (e) {
          print('下载图片失败 ${record.id}: $e');
        }
      }

      _notifyStatus('已下载 $downloaded 张图片');
      _notifyDataChanged();
    } catch (e) {
      print('批量下载图片失败：$e');
    }
  }

  /// 下载所有缺失的图片
  Future<void> _downloadAllImages() async {
    try {
      final allMeals = HiveService.allMealRecords;
      final needDownload = <MealPhotoRecord>[];

      for (final record in allMeals) {
        if (!await ImageDownloadService.isImageCached(record.id)) {
          needDownload.add(record);
        }
      }

      if (needDownload.isNotEmpty) {
        _notifyStatus('正在下载 ${needDownload.length} 张图片...');
        await _downloadImagesInBackground(needDownload);
      }
    } catch (e) {
      print('下载所有图片失败：$e');
    }
  }

  /// 从服务器删除血糖记录
  Future<void> deleteGlucoseFromCloud(String id) async {
    try {
      await _api.deleteGlucoseRecord(id);
      print('已删除云端血糖记录：$id');
    } catch (e) {
      print('删除云端血糖记录失败：$e');
    }
  }

  /// 从服务器删除饮食记录
  Future<void> deleteMealFromCloud(String id) async {
    try {
      await _api.deleteMealRecord(id);
      print('已删除云端饮食记录：$id');
    } catch (e) {
      print('删除云端饮食记录失败：$e');
    }
  }

  /// 打开历史/统计页面时自动校准同步
  Future<void> calibrateAndSync() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      await _initDeviceId();
      _notifyStatus('校准并同步...');

      // 校准时间
      await calibrateTime();

      // 1. 先上传本地数据到服务器（确保刚添加的数据不会丢失）
      _notifyStatus('正在上传本地数据...');
      try {
        await _uploadLocalData();
      } catch (e) {
        print('上传本地数据失败：$e');
        // 上传失败不阻塞，继续下载
      }

      // 2. 从服务器获取所有数据
      _notifyStatus('正在下载服务器数据...');
      final result = await _api.incrementalSync(
        lastSyncTime: null,
        deviceIds: null,
      );

      // 3. 替换本地数据
      await _replaceGlucoseRecords(result.glucoseRecords);
      await _replaceMealRecords(result.mealRecords);

      _lastSyncTime = _api.serverTime ?? DateTime.now();
      _notifyStatus('校准完成');

      // 通知刷新
      _notifyDataChanged();
    } catch (e) {
      _notifyStatus('校准失败：$e');
      print('校准同步失败：$e');
    } finally {
      _isSyncing = false;
    }
  }

  /// 仅上传本地新增数据
  Future<void> syncLocalChanges() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      _notifyStatus('同步更改...');

      await _uploadLocalData();

      _lastSyncTime = _api.serverTime ?? DateTime.now();
      _notifyStatus('同步完成');
    } catch (e) {
      _notifyStatus('同步失败：$e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// 从云端下载数据到本地
  Future<void> downloadFromCloud() async {
    if (_isSyncing) return;

    try {
      _isSyncing = true;
      _notifyStatus('从云端下载...');

      await _downloadRemoteData(lastSyncTime: null);

      _lastSyncTime = _api.serverTime ?? DateTime.now();
      _notifyStatus('下载完成');
      _notifyDataChanged();
    } catch (e) {
      _notifyStatus('下载失败：$e');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// 下载云端数据（增量）
  Future<void> _downloadRemoteData({DateTime? lastSyncTime}) async {
    _notifyStatus('正在下载云端数据...');

    try {
      final result = await _api.incrementalSync(
        lastSyncTime: null,
        deviceIds: null,
      );

      await _replaceGlucoseRecords(result.glucoseRecords);
      await _replaceMealRecords(result.mealRecords);
    } catch (e) {
      print('下载云端数据失败：$e');
      rethrow;
    }
  }

  /// 获取同步状态
  Future<SyncStatus?> getSyncStatus() async {
    try {
      return await _api.getSyncStatus();
    } catch (e) {
      print('获取同步状态失败：$e');
      return null;
    }
  }

  void _notifyStatus(String status) {
    print('[CloudSync] $status');
    onStatusUpdate?.call(status);
  }

  void _notifyProgress(int progress) {
    onProgressUpdate?.call(progress);
  }

  void _notifyDataChanged() {
    print('[CloudSync] 数据已变更，通知刷新');
    onDataChanged?.call();
  }

  void dispose() {
    _api.dispose();
  }
}
