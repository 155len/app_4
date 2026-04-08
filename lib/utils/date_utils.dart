import 'package:intl/intl.dart';

/// 日期工具类
class DateUtils {
  /// 格式化日期为显示格式
  static String formatDate(DateTime date, {bool showYear = false}) {
    if (showYear) {
      return DateFormat('yyyy 年 MM 月 dd 日').format(date);
    }
    return DateFormat('MM 月 dd 日').format(date);
  }

  /// 格式化时间为显示格式
  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  /// 格式化日期时间
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MM-dd HH:mm').format(dateTime);
  }

  /// 获取相对时间描述
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return formatDate(dateTime, showYear: true);
    }
  }

  /// 判断是否是今天
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// 判断是否是昨天
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// 获取日期范围的字符串表示
  static String formatRange(DateTime start, DateTime end) {
    if (isSameDay(start, end)) {
      return formatDate(start);
    }

    final sameMonth = start.year == end.year && start.month == end.month;
    if (sameMonth) {
      return '${start.month}月${start.day}日 - ${end.day}日';
    }

    return '${formatDate(start)} - ${formatDate(end)}';
  }

  /// 判断两个日期是否在同一天
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 获取一周的日期列表（从周一到周日）
  static List<DateTime> getWeekDays([DateTime? from]) {
    final date = from ?? DateTime.now();
    // 获取周一（Dart 中 weekday: 1=周一，7=周日）
    final monday = date.subtract(Duration(days: date.weekday - 1));

    return List.generate(7, (index) {
      return monday.add(Duration(days: index));
    });
  }

  /// 获取一个月的所有日期
  static List<DateTime> getMonthDays(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return List.generate(lastDay, (index) {
      return DateTime(year, month, index + 1);
    });
  }

  /// 获取日期的开始时间
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 获取日期的结束时间
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  /// 获取前一周的开始日期
  static DateTime getPreviousWeekStart([DateTime? from]) {
    final date = from ?? DateTime.now();
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return monday.subtract(const Duration(days: 7));
  }

  /// 获取前一个月的开始日期
  static DateTime getPreviousMonthStart([DateTime? from]) {
    final date = from ?? DateTime.now();
    return DateTime(date.year, date.month - 1, 1);
  }
}
