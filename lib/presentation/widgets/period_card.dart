import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/blood_glucose.dart';
import '../../domain/entities/time_period.dart';
import '../../config/theme.dart';

/// 时段卡片组件 - 显示某时段的血糖记录
class PeriodCard extends StatelessWidget {
  final TimePeriod period;
  final BloodGlucoseRecord? record;
  final bool isMissing;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const PeriodCard({
    super.key,
    required this.period,
    this.record,
    this.isMissing = false,
    this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final periodName = getPeriodName(period);
    final timeRange = getPeriodTimeRange(period);

    return Card(
      elevation: isMissing ? 4 : 2,
      color: isMissing ? Colors.orange[50] : null,
      child: InkWell(
        onTap: record != null ? onTap : onAddTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 时段信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      periodName,
                      style: const TextStyle(
                        fontSize: AppTheme.textSizeNormal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeRange,
                      style: const TextStyle(
                        fontSize: AppTheme.textSizeSmall,
                        color: Colors.grey,
                      ),
                    ),
                    if (isMissing) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '未测量',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 血糖值或添加按钮
              if (record != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${record!.value}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getGlucoseColor(record!.value),
                      ),
                    ),
                    Text(
                      'mmol/L',
                      style: const TextStyle(
                        fontSize: AppTheme.textSizeSmall,
                        color: Colors.grey,
                      ),
                    ),
                    if (record != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('HH:mm').format(record!.timestamp),
                        style: const TextStyle(
                          fontSize: AppTheme.textSizeSmall,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 32),
                  color: AppTheme.primaryColor,
                  onPressed: onAddTap,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 提醒横幅组件 - 显示未测量提醒
class ReminderBanner extends StatelessWidget {
  final List<TimePeriod> missingPeriods;
  final VoidCallback? onTap;

  const ReminderBanner({
    super.key,
    required this.missingPeriods,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (missingPeriods.isEmpty) {
      return const SizedBox.shrink();
    }

    final periodNames = missingPeriods
        .map((p) => getPeriodName(p, short: true))
        .join(',');

    return Card(
      color: Colors.orange[100],
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active,
                color: Colors.orange,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '未测量提醒',
                      style: TextStyle(
                        fontSize: AppTheme.textSizeNormal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '您还没有记录 $periodNames 的血糖',
                      style: const TextStyle(
                        fontSize: AppTheme.textSizeSmall,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
