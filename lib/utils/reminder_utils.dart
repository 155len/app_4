import '../domain/entities/time_period.dart';
import '../data/models/meal_photo.dart';

/// 提醒工具类
class ReminderUtils {
  /// 检查是否需要提醒测量血糖
  /// 返回未测量的时段列表
  static List<TimePeriod> checkMissingMeasurements(
    List<dynamic> todayRecords,
  ) {
    final now = DateTime.now();
    final currentPeriod = getPeriodFromTime(now);
    final expectedPeriods = _getExpectedPeriodsBefore(currentPeriod, now);

    return expectedPeriods
        .where((period) => !todayRecords.any((r) => r.period == period))
        .toList();
  }

  /// 获取当前时间之前应该已完成的时段
  static List<TimePeriod> _getExpectedPeriodsBefore(
    TimePeriod currentPeriod,
    DateTime now,
  ) {
    final hour = now.hour;
    final minute = now.minute;
    List<TimePeriod> expected = [];

    // 空腹：5:00-7:00，7:00 后检查
    if (hour >= 7) {
      expected.add(TimePeriod.fasting);
    }

    // 早餐前：7:00-7:30，7:30 后检查
    if (hour >= 7 && minute >= 30) {
      expected.add(TimePeriod.beforeBreakfast);
    }

    // 早餐后：7:30-11:00，11:00 后检查
    if (hour >= 11) {
      expected.add(TimePeriod.afterBreakfast);
    }

    // 午餐前：11:00-12:00，12:00 后检查
    if (hour >= 12) {
      expected.add(TimePeriod.beforeLunch);
    }

    // 午餐后：12:00-14:00，14:00 后检查
    if (hour >= 14) {
      expected.add(TimePeriod.afterLunch);
    }

    // 晚餐前：14:00-18:00，18:00 后检查
    if (hour >= 18) {
      expected.add(TimePeriod.beforeDinner);
    }

    // 晚餐后：18:00-21:00，21:00 后检查
    if (hour >= 21) {
      expected.add(TimePeriod.afterDinner);
    }

    // 睡前：21:00-23:00，23:00 后检查
    if (hour >= 23) {
      expected.add(TimePeriod.bedtime);
    }

    return expected;
  }

  /// 获取提醒消息
  static String getReminderMessage(TimePeriod period) {
    switch (period) {
      case TimePeriod.fasting:
        return '您还没有记录空腹血糖，请测量并记录';
      case TimePeriod.beforeBreakfast:
        return '您还没有记录早餐前血糖，请在用餐前测量';
      case TimePeriod.afterBreakfast:
        return '您还没有记录早餐后血糖，请在用餐后 2 小时测量';
      case TimePeriod.beforeLunch:
        return '您还没有记录午餐前血糖，请在用餐前测量';
      case TimePeriod.afterLunch:
        return '您还没有记录午餐后血糖，请在用餐后 2 小时测量';
      case TimePeriod.beforeDinner:
        return '您还没有记录晚餐前血糖，请在用餐前测量';
      case TimePeriod.afterDinner:
        return '您还没有记录晚餐后血糖，请在用餐后 2 小时测量';
      case TimePeriod.bedtime:
        return '您还没有记录睡前血糖，请测量并记录';
    }
  }

  /// 检查是否需要提醒吃药
  static List<MealPhotoRecord> checkMedicineReminder(
    List<MealPhotoRecord> mealRecords,
  ) {
    final now = DateTime.now();
    return mealRecords.where((record) {
      // 已吃药的不需要提醒
      if (record.medicineTaken) return false;

      // 检查是否到了提醒时间（饭后 30 分钟）
      final remindTime = record.timestamp.add(const Duration(minutes: 30));
      return now.isAfter(remindTime);
    }).toList();
  }

  /// 获取吃药提醒消息
  static String getMedicineReminderMessage(MealPhotoRecord record) {
    final mealName = record.mealTypeName;
    final timeStr = record.timestamp.hour.toString().padLeft(2, '0') +
        ':' +
        record.timestamp.minute.toString().padLeft(2, '0');

    return '您在$timeStr 记录了$mealName，现在是时候服用降糖药了！';
  }

  /// 获取时段对应的测量建议
  static String getMeasurementSuggestion(TimePeriod period) {
    switch (period) {
      case TimePeriod.fasting:
        return '空腹血糖正常值：3.9-6.1 mmol/L';
      case TimePeriod.beforeBreakfast:
      case TimePeriod.beforeLunch:
      case TimePeriod.beforeDinner:
        return '餐前血糖正常值：4.4-6.1 mmol/L';
      case TimePeriod.afterBreakfast:
      case TimePeriod.afterLunch:
      case TimePeriod.afterDinner:
        return '餐后 2 小时血糖正常值：<7.8 mmol/L';
      case TimePeriod.bedtime:
        return '睡前血糖正常值：5.6-7.8 mmol/L';
    }
  }

  /// 根据血糖值返回健康提示
  static String getHealthTip(double value, TimePeriod period) {
    // 简化判断，适用于一般情况
    if (value < 3.9) {
      return '⚠️ 血糖偏低，建议立即补充糖分，如糖果、果汁等';
    } else if (value <= 6.1) {
      return '✓ 血糖控制良好，继续保持！';
    } else if (value <= 7.0) {
      return '血糖略高，注意饮食控制和适量运动';
    } else if (value <= 10.0) {
      return '⚠️ 血糖偏高，建议咨询医生调整治疗方案';
    } else {
      return '⚠️ 血糖过高，请尽快就医';
    }
  }
}
