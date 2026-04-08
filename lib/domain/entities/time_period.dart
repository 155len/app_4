/// 时段枚举 - 用于区分一天中的不同测量时段
enum TimePeriod {
  fasting,      // 空腹
  beforeBreakfast,  // 早餐前
  afterBreakfast,   // 早餐后
  beforeLunch,      // 午餐前
  afterLunch,       // 午餐后
  beforeDinner,     // 晚餐前
  afterDinner,      // 晚餐后
  bedtime,          // 睡前
}

/// 根据时间获取时段
TimePeriod getPeriodFromTime(DateTime time) {
  final hour = time.hour;

  // 空腹：起床后到早餐前 (5:00-7:00)
  if (hour >= 5 && hour < 7) {
    return TimePeriod.fasting;
  }
  // 早餐时段 (7:00-9:00)
  if (hour >= 7 && hour < 9) {
    return time.minute < 30 ? TimePeriod.beforeBreakfast : TimePeriod.afterBreakfast;
  }
  // 上午加餐 (9:00-11:00)
  if (hour >= 9 && hour < 11) {
    return TimePeriod.afterBreakfast;
  }
  // 午餐前 (11:00-12:00)
  if (hour >= 11 && hour < 12) {
    return TimePeriod.beforeLunch;
  }
  // 午餐后 (12:00-14:00)
  if (hour >= 12 && hour < 14) {
    return TimePeriod.afterLunch;
  }
  // 晚餐前 (14:00-18:00)
  if (hour >= 14 && hour < 18) {
    return TimePeriod.beforeDinner;
  }
  // 晚餐后 (18:00-21:00)
  if (hour >= 18 && hour < 21) {
    return TimePeriod.afterDinner;
  }
  // 睡前 (21:00-23:00)
  if (hour >= 21 && hour < 23) {
    return TimePeriod.bedtime;
  }

  // 深夜默认空腹
  return TimePeriod.fasting;
}

/// 获取时段的显示名称
String getPeriodName(TimePeriod period, {bool short = false}) {
  switch (period) {
    case TimePeriod.fasting:
      return short ? '空腹' : '空腹血糖';
    case TimePeriod.beforeBreakfast:
      return short ? '早前' : '早餐前';
    case TimePeriod.afterBreakfast:
      return short ? '早后' : '早餐后';
    case TimePeriod.beforeLunch:
      return short ? '午前' : '午餐前';
    case TimePeriod.afterLunch:
      return short ? '午后' : '午餐后';
    case TimePeriod.beforeDinner:
      return short ? '晚前' : '晚餐前';
    case TimePeriod.afterDinner:
      return short ? '晚后' : '晚餐后';
    case TimePeriod.bedtime:
      return short ? '睡前' : '睡前血糖';
  }
}

/// 获取时段的时间范围描述
String getPeriodTimeRange(TimePeriod period) {
  switch (period) {
    case TimePeriod.fasting:
      return '5:00-7:00';
    case TimePeriod.beforeBreakfast:
      return '7:00-7:30';
    case TimePeriod.afterBreakfast:
      return '7:30-11:00';
    case TimePeriod.beforeLunch:
      return '11:00-12:00';
    case TimePeriod.afterLunch:
      return '12:00-14:00';
    case TimePeriod.beforeDinner:
      return '14:00-18:00';
    case TimePeriod.afterDinner:
      return '18:00-21:00';
    case TimePeriod.bedtime:
      return '21:00-23:00';
  }
}
