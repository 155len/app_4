import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/blood_glucose.dart';
import '../../data/repositories/glucose_repository.dart';
import '../../data/remote/cloud_api_service.dart';
import '../../data/remote/cloud_sync_service.dart';
import '../../domain/entities/time_period.dart';
import '../../data/local/hive_service.dart';

/// 血糖数据状态
class GlucoseState {
  final List<BloodGlucoseRecord> records;
  final List<BloodGlucoseRecord> todayRecords;
  final Map<TimePeriod, BloodGlucoseRecord?> todayByPeriod;
  final List<TimePeriod> missingPeriods;
  final bool isLoading;
  final String? error;

  GlucoseState({
    this.records = const [],
    this.todayRecords = const [],
    Map<TimePeriod, BloodGlucoseRecord?>? todayByPeriod,
    this.missingPeriods = const [],
    this.isLoading = false,
    this.error,
  }) : todayByPeriod = todayByPeriod ?? {};

  GlucoseState copyWith({
    List<BloodGlucoseRecord>? records,
    List<BloodGlucoseRecord>? todayRecords,
    Map<TimePeriod, BloodGlucoseRecord?>? todayByPeriod,
    List<TimePeriod>? missingPeriods,
    bool? isLoading,
    String? error,
  }) {
    return GlucoseState(
      records: records ?? this.records,
      todayRecords: todayRecords ?? this.todayRecords,
      todayByPeriod: todayByPeriod ?? this.todayByPeriod,
      missingPeriods: missingPeriods ?? this.missingPeriods,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// 获取某时段的记录
  BloodGlucoseRecord? getRecordForPeriod(TimePeriod period) {
    return todayByPeriod[period];
  }

  /// 检查某时段是否有记录
  bool hasRecordForPeriod(TimePeriod period) {
    return todayByPeriod[period] != null;
  }
}

/// 血糖数据 Provider
final glucoseProvider = StateNotifierProvider<GlucoseNotifier, GlucoseState>((ref) {
  return GlucoseNotifier();
});

class GlucoseNotifier extends StateNotifier<GlucoseState> {
  final CloudApiService _api = CloudApiService();
  final CloudSyncService _syncService = CloudSyncService();

  GlucoseNotifier() : super(GlucoseState()) {
    // 监听同步服务的数据变化
    _syncService.onDataChanged = _onDataChanged;
    loadAll();
  }

  /// 数据变化通知（来自同步服务）
  void _onDataChanged() {
    print('[GlucoseProvider] 数据已变更，刷新状态');
    loadAll();
  }

  /// 加载所有数据（从本地缓存读取）
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 从本地 Hive 读取数据（服务器数据已同步到本地）
      final allRecords = _getAllFromLocal();
      final todayRecords = _getTodayFromLocal();
      final todayByPeriod = _getTodayByPeriodFromLocal();
      final missingPeriods = _getMissingPeriodsFromLocal();

      state = state.copyWith(
        records: allRecords,
        todayRecords: todayRecords,
        todayByPeriod: todayByPeriod,
        missingPeriods: missingPeriods,
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
  List<BloodGlucoseRecord> _getAllFromLocal() {
    return HiveService.allGlucoseRecords
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// 从本地获取今日记录
  List<BloodGlucoseRecord> _getTodayFromLocal() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _getAllFromLocal()
      ..where((r) => r.timestamp.isAfter(today.subtract(const Duration(days: 1))))
      .toList();
  }

  /// 从本地获取今日各时段记录
  Map<TimePeriod, BloodGlucoseRecord?> _getTodayByPeriodFromLocal() {
    final today = _getTodayFromLocal();
    final map = <TimePeriod, BloodGlucoseRecord?>{};

    for (final period in TimePeriod.values) {
      map[period] = today.where((r) => r.period == period).lastOrNull;
    }

    return map;
  }

  /// 从本地获取未测量时段
  List<TimePeriod> _getMissingPeriodsFromLocal() {
    final today = _getTodayFromLocal();
    final now = DateTime.now();
    final currentPeriod = _getPeriodFromTime(now);

    final expectedPeriods = _getExpectedPeriodsBefore(currentPeriod);

    return expectedPeriods
      ..where((period) => !today.any((r) => r.period == period))
      .toList();
  }

  TimePeriod _getPeriodFromTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;

    if (hour >= 5 && hour < 7) return TimePeriod.fasting;
    if (hour == 7 && minute < 30) return TimePeriod.beforeBreakfast;
    if ((hour == 7 && minute >= 30) || (hour >= 8 && hour < 11)) return TimePeriod.afterBreakfast;
    if (hour >= 11 && hour < 12) return TimePeriod.beforeLunch;
    if (hour >= 12 && hour < 14) return TimePeriod.afterLunch;
    if (hour >= 14 && hour < 18) return TimePeriod.beforeDinner;
    if (hour >= 18 && hour < 21) return TimePeriod.afterDinner;
    if (hour >= 21 && hour < 23) return TimePeriod.bedtime;
    return TimePeriod.bedtime;
  }

  List<TimePeriod> _getExpectedPeriodsBefore(TimePeriod currentPeriod) {
    final now = DateTime.now();
    final hour = now.hour;

    List<TimePeriod> expected = [];

    if (hour >= 7) expected.add(TimePeriod.fasting);
    if (hour >= 7 && now.minute >= 30) expected.add(TimePeriod.beforeBreakfast);
    if (hour >= 11 || (hour == 10 && now.minute >= 30)) expected.add(TimePeriod.afterBreakfast);
    if (hour >= 12) expected.add(TimePeriod.beforeLunch);
    if (hour >= 14) expected.add(TimePeriod.afterLunch);
    if (hour >= 18) expected.add(TimePeriod.beforeDinner);
    if (hour >= 21) expected.add(TimePeriod.afterDinner);
    if (hour >= 23) expected.add(TimePeriod.bedtime);

    return expected;
  }

  /// 添加血糖记录（先保存到本地，然后异步上传到服务器）
  Future<bool> addRecord(BloodGlucoseRecord record) async {
    try {
      // 1. 保存到本地
      await HiveService.addGlucoseRecord(record);

      // 2. 异步上传到服务器
      _uploadToCloud(record);

      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 上传单条记录到服务器（后台任务）
  Future<void> _uploadToCloud(BloodGlucoseRecord record) async {
    try {
      await _api.uploadGlucoseRecord(record);
      print('血糖记录已上传到服务器：${record.id}');
    } catch (e) {
      print('上传血糖记录失败：$e');
    }
  }

  /// 删除血糖记录（同时删除本地和云端）
  Future<void> deleteRecord(String id) async {
    try {
      // 1. 先删除本地数据
      await HiveService.deleteGlucoseRecord(id);

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
      await _api.deleteGlucoseRecord(id);
      print('血糖记录已从云端删除：$id');
    } catch (e) {
      print('删除云端血糖记录失败：$e');
    }
  }

  /// 刷新今日数据
  Future<void> refreshToday() async {
    final todayRecords = _getTodayFromLocal();
    final todayByPeriod = _getTodayByPeriodFromLocal();
    final missingPeriods = _getMissingPeriodsFromLocal();

    state = state.copyWith(
      todayRecords: todayRecords,
      todayByPeriod: todayByPeriod,
      missingPeriods: missingPeriods,
    );
  }

  /// 获取统计数据
  Map<String, dynamic> getStatistics({DateTime? start, DateTime? end}) {
    final records = _getAllFromLocal();

    if (records.isEmpty) {
      return {
        'count': 0,
        'average': null,
        'min': null,
        'max': null,
        'fastingAverage': null,
        'postMealAverage': null,
      };
    }

    final filteredRecords = start != null && end != null
      ? records.where((r) => r.timestamp.isAfter(start) && r.timestamp.isBefore(end)).toList()
      : records;

    if (filteredRecords.isEmpty) {
      return {
        'count': 0,
        'average': null,
        'min': null,
        'max': null,
        'fastingAverage': null,
        'postMealAverage': null,
      };
    }

    final values = filteredRecords.map((r) => r.value).toList();
    final fastingRecords = filteredRecords.where((r) => r.period == TimePeriod.fasting).toList();
    final postMealRecords = filteredRecords.where((r) => r.isPostMeal).toList();

    return {
      'count': filteredRecords.length,
      'average': values.reduce((a, b) => a + b) / values.length,
      'min': values.reduce((a, b) => a < b ? a : b),
      'max': values.reduce((a, b) => a > b ? a : b),
      'fastingAverage': fastingRecords.isNotEmpty
        ? fastingRecords.map((r) => r.value).reduce((a, b) => a + b) / fastingRecords.length
        : null,
      'postMealAverage': postMealRecords.isNotEmpty
        ? postMealRecords.map((r) => r.value).reduce((a, b) => a + b) / postMealRecords.length
        : null,
    };
  }
}
