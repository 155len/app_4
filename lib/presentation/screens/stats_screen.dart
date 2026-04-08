import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../providers/glucose_provider.dart';
import '../../data/remote/cloud_sync_service.dart';
import '../../data/models/blood_glucose.dart';

/// 统计图表页面
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String _selectedPeriod = 'week'; // week, month, all
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // 页面加载时自动校准同步
    _autoCalibrate();
  }

  /// 自动校准同步（只拉取本地缺少的数据）
  Future<void> _autoCalibrate() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      await CloudSyncService().calibrateAndSync();
    } catch (e) {
      print('自动校准失败：$e');
      // 校准失败不影响使用
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glucoseState = ref.watch(glucoseProvider);
    final stats = ref.read(glucoseProvider.notifier).getStatistics(
      start: _getStartDate(),
      end: DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('数据统计'),
            if (_isSyncing) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isSyncing ? null : _autoCalibrate,
            tooltip: '同步数据',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 周期选择
          _buildPeriodSelector(),
          const SizedBox(height: 16),
          // 统计摘要卡片
          _buildSummaryCards(stats),
          const SizedBox(height: 16),
          // 血糖趋势图
          _buildTrendChart(glucoseState.records),
          const SizedBox(height: 16),
          // 分布统计
          _buildDistributionCard(stats),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'week', label: Text('近 7 天')),
        ButtonSegment(value: 'month', label: Text('近 30 天')),
        ButtonSegment(value: 'all', label: Text('全部')),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (set) {
        setState(() => _selectedPeriod = set.first);
      },
    );
  }

  DateTime? _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'week':
        return now.subtract(const Duration(days: 7));
      case 'month':
        return now.subtract(const Duration(days: 30));
      default:
        return null;
    }
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: '平均血糖',
                value: stats['average'] != null
                    ? (stats['average'] as num).toStringAsFixed(1)
                    : '--',
                unit: 'mmol/L',
                icon: Icons.show_chart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: '最高血糖',
                value: stats['max'] != null
                    ? '${stats['max']}'
                    : '--',
                unit: 'mmol/L',
                icon: Icons.arrow_upward,
                color: AppTheme.glucoseHigh,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: '最低血糖',
                value: stats['min'] != null
                    ? '${stats['min']}'
                    : '--',
                unit: 'mmol/L',
                icon: Icons.arrow_downward,
                color: AppTheme.glucoseLow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: '空腹平均',
                value: stats['fastingAverage'] != null
                    ? (stats['fastingAverage'] as num).toStringAsFixed(1)
                    : '--',
                unit: 'mmol/L',
                icon: Icons.bedtime_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: '餐后平均',
                value: stats['postMealAverage'] != null
                    ? (stats['postMealAverage'] as num).toStringAsFixed(1)
                    : '--',
                unit: 'mmol/L',
                icon: Icons.restaurant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: '记录次数',
                value: '${stats['count']}',
                unit: '次',
                icon: Icons.assignment,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendChart(List<BloodGlucoseRecord> records) {
    final startDate = _getStartDate();
    final filteredRecords = startDate == null
        ? records
        : records.where((r) => r.timestamp.isAfter(startDate)).toList();

    if (filteredRecords.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                const Icon(
                  Icons.insights,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  '暂无数据',
                  style: TextStyle(
                    fontSize: AppTheme.textSizeNormal,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '开始记录血糖后即可查看趋势图',
                  style: const TextStyle(
                    fontSize: AppTheme.textSizeSmall,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 按时间排序所有记录
    final sortedRecords = List<BloodGlucoseRecord>.from(filteredRecords)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 生成数据点：每个测量值作为一个点
    final spots = <FlSpot>[];
    final spotLabels = <int, String>{}; // 索引 -> 日期时间标签
    final dateLabels = <String>{}; // 用于 X 轴显示的日期标签

    for (int i = 0; i < sortedRecords.length; i++) {
      final record = sortedRecords[i];
      spots.add(FlSpot(i.toDouble(), record.value));

      // 生成标签（日期 + 时间）
      final dateStr = DateFormat('MM-dd').format(record.timestamp);
      final timeStr = DateFormat('HH:mm').format(record.timestamp);
      spotLabels[i] = '$dateStr $timeStr';
      dateLabels.add(dateStr);
    }

    // 计算 Y 轴范围
    final values = sortedRecords.map((r) => r.value).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxValue - minValue) * 0.15;
    final minY = ((minValue - padding).clamp(0, minValue - 0.5)).toDouble();
    final maxY = (maxValue + padding).toDouble();

    // 生成 X 轴标签（时间 + 日期，每条记录都显示）- 日期在上，时间在下
    final xAxisLabels = <int, String>{};
    for (int i = 0; i < sortedRecords.length; i++) {
      final dateStr = DateFormat('MM-dd').format(sortedRecords[i].timestamp);
      final timeStr = DateFormat('HH:mm').format(sortedRecords[i].timestamp);
      xAxisLabels[i] = '$dateStr\n$timeStr'; // 上日期下时间
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '血糖趋势',
              style: TextStyle(
                fontSize: AppTheme.textSizeLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    verticalInterval: spots.length > 1 ? 1 : null,
                    horizontalInterval: _getInterval(minY, maxY),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withAlpha(50),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withAlpha(30),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: _getInterval(minY, maxY),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sortedRecords.length) {
                            return const Text('');
                          }
                          final label = xAxisLabels[index];
                          if (label == null) {
                            return const Text('');
                          }
                          // 根据数据点数量动态调整显示密度
                          final shouldShow = sortedRecords.length <= 10 ||
                              (sortedRecords.length <= 20 && index % 2 == 0) ||
                              index % 3 == 0;
                          if (!shouldShow) {
                            return const Text('');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.withAlpha(50)),
                  ),
                  minX: 0,
                  maxX: spots.length > 1 ? (spots.length - 1).toDouble() : 1,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false, // 折线图，不使用曲线
                      barWidth: 2,
                      color: AppTheme.primaryColor,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final record = sortedRecords[index];
                          final color = _getValueColor(record.value);
                          return FlDotCirclePainter(
                            radius: 5,
                            color: color,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withAlpha(60),
                            AppTheme.primaryColor.withAlpha(10),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.grey[800]!,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final record = sortedRecords[spot.x.toInt()];
                          final dateStr = DateFormat('MM-dd HH:mm').format(record.timestamp);
                          return LineTooltipItem(
                            '$dateStr\n${record.value} mmol/L',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            // 图例
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendDot(AppTheme.glucoseNormal),
                  const SizedBox(width: 4),
                  const Text('正常 (3.9-6.1)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 12),
                  _buildLegendDot(AppTheme.glucoseLow),
                  const SizedBox(width: 4),
                  const Text('略高 (6.1-7.8)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 12),
                  _buildLegendDot(AppTheme.glucoseHigh),
                  const SizedBox(width: 4),
                  const Text('偏高 (7.8-10)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 12),
                  _buildLegendDot(Colors.red),
                  const SizedBox(width: 4),
                  const Text('过高 (>10)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
  }

  Color _getLineColor(int spotIndex, double percent) {
    return AppTheme.primaryColor;
  }

  Color _getValueColor(double value) {
    return AppTheme.getGlucoseColor(value);
  }

  double _getInterval(double min, double max) {
    final range = max - min;
    if (range < 3) return 1;
    if (range < 6) return 2;
    return 3;
  }

  Widget _buildDistributionCard(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '血糖分布',
              style: TextStyle(
                fontSize: AppTheme.textSizeLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _DistributionRow(
              label: '正常范围',
              range: '3.9-6.1 mmol/L',
              color: AppTheme.glucoseNormal,
            ),
            const SizedBox(height: 8),
            _DistributionRow(
              label: '略高',
              range: '6.1-7.8 mmol/L',
              color: AppTheme.glucoseLow,
            ),
            const SizedBox(height: 8),
            _DistributionRow(
              label: '偏高',
              range: '7.8-10.0 mmol/L',
              color: AppTheme.glucoseHigh,
            ),
            const SizedBox(height: 8),
            _DistributionRow(
              label: '过高',
              range: '>10.0 mmol/L',
              color: Colors.red[900]!,
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyValue {
  final double sum;
  final int count;
  _DailyValue({required this.sum, required this.count});
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color? color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? AppTheme.primaryColor, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppTheme.textSizeSmall,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.black87,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 10,
                    color: color ?? Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final String label;
  final String range;
  final Color color;

  const _DistributionRow({
    required this.label,
    required this.range,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label ($range)',
            style: const TextStyle(fontSize: AppTheme.textSizeSmall),
          ),
        ),
      ],
    );
  }
}
