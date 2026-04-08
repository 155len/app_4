import '../models/blood_glucose.dart';
import '../local/hive_service.dart';
import '../../domain/entities/time_period.dart';

/// 血糖数据仓库
/// 预留云同步接口：未来可实现 CloudGlucoseRepository 继承自 BaseGlucoseRepository
class GlucoseRepository {
  // 私有构造函数，防止实例化
  GlucoseRepository._();

  static final GlucoseRepository _instance = GlucoseRepository._();

  factory GlucoseRepository() => _instance;

  /// 获取所有血糖记录
  List<BloodGlucoseRecord> getAll() {
    return HiveService.allGlucoseRecords
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// 获取今日血糖记录
  List<BloodGlucoseRecord> getTodayRecords() {
    final now = DateTime.now();
    return getByDate(now);
  }

  /// 获取指定日期的血糖记录
  List<BloodGlucoseRecord> getByDate(DateTime date) {
    return HiveService.getGlucoseRecordsByDate(_normalizeDate(date))
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// 获取日期范围的血糖记录
  List<BloodGlucoseRecord> getByRange(DateTime start, DateTime end) {
    return HiveService.getGlucoseRecordsByRange(
            _normalizeDate(start), _normalizeDate(end))
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// 获取指定时段的数据
  List<BloodGlucoseRecord> getByPeriod(DateTime date, TimePeriod period) {
    final records = getByDate(date);
    return records.where((r) => r.period == period).toList();
  }

  /// 添加血糖记录
  Future<BloodGlucoseRecord> add(BloodGlucoseRecord record) async {
    await HiveService.addGlucoseRecord(record);
    return record;
  }

  /// 更新血糖记录
  Future<void> update(BloodGlucoseRecord record) async {
    await HiveService.updateGlucoseRecord(record);
  }

  /// 删除血糖记录
  Future<void> delete(String id) async {
    await HiveService.deleteGlucoseRecord(id);
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    await HiveService.clearAllGlucoseRecords();
  }

  /// 获取最新的一条记录
  BloodGlucoseRecord? getLatest() {
    final all = getAll();
    return all.isNotEmpty ? all.first : null;
  }

  /// 获取今日各时段的记录
  Map<TimePeriod, BloodGlucoseRecord?> getTodayByPeriod() {
    final today = getTodayRecords();
    final map = <TimePeriod, BloodGlucoseRecord?>{};

    for (final period in TimePeriod.values) {
      map[period] = today.where((r) => r.period == period).lastOrNull;
    }

    return map;
  }

  /// 检查今日某时段是否有记录
  bool hasRecordForPeriod(TimePeriod period) {
    final today = getTodayRecords();
    return today.any((r) => r.period == period);
  }

  /// 获取未测量的时段
  List<TimePeriod> getMissingPeriods() {
    final today = getTodayRecords();
    final now = DateTime.now();
    final currentPeriod = getPeriodFromTime(now);

    // 获取当前时间之前应该已经测量的时段
    final expectedPeriods = _getExpectedPeriodsBefore(currentPeriod);

    return expectedPeriods
        .where((period) => !today.any((r) => r.period == period))
        .toList();
  }

  /// 获取某时段应该测量的时间之前应该完成的时段
  List<TimePeriod> _getExpectedPeriodsBefore(TimePeriod currentPeriod) {
    final now = DateTime.now();
    final hour = now.hour;

    List<TimePeriod> expected = [];

    // 空腹：5:00-7:00
    if (hour >= 7) {
      expected.add(TimePeriod.fasting);
    }

    // 早餐前：7:00-7:30
    if (hour >= 7 && now.minute >= 30) {
      expected.add(TimePeriod.beforeBreakfast);
    }

    // 早餐后：7:30-11:00
    if (hour >= 11 || (hour == 10 && now.minute >= 30)) {
      expected.add(TimePeriod.afterBreakfast);
    }

    // 午餐前：11:00-12:00
    if (hour >= 12) {
      expected.add(TimePeriod.beforeLunch);
    }

    // 午餐后：12:00-14:00
    if (hour >= 14) {
      expected.add(TimePeriod.afterLunch);
    }

    // 晚餐前：14:00-18:00
    if (hour >= 18) {
      expected.add(TimePeriod.beforeDinner);
    }

    // 晚餐后：18:00-21:00
    if (hour >= 21) {
      expected.add(TimePeriod.afterDinner);
    }

    // 睡前：21:00-23:00
    if (hour >= 23) {
      expected.add(TimePeriod.bedtime);
    }

    return expected;
  }

  /// 标准化日期（只保留年月日）
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 计算平均血糖值
  double? getAverageValue({DateTime? start, DateTime? end}) {
    List<BloodGlucoseRecord> records;

    if (start != null && end != null) {
      records = getByRange(start, end);
    } else {
      records = getAll();
    }

    if (records.isEmpty) return null;

    final sum = records.fold<double>(0, (sum, r) => sum + r.value);
    return sum / records.length;
  }

  /// 获取统计数据
  Map<String, dynamic> getStatistics({DateTime? start, DateTime? end}) {
    List<BloodGlucoseRecord> records;

    if (start != null && end != null) {
      records = getByRange(start, end);
    } else {
      records = getAll();
    }

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

    final values = records.map((r) => r.value).toList();
    final fastingRecords = records.where((r) => r.period == TimePeriod.fasting).toList();
    final postMealRecords = records.where((r) => r.isPostMeal).toList();

    return {
      'count': records.length,
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
