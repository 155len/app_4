import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../data/local/export_service.dart';
import '../../data/models/blood_glucose.dart';
import '../../data/models/meal_photo.dart';
import '../../domain/entities/time_period.dart';
import '../../domain/entities/meal_type.dart';
import '../../data/remote/cloud_sync_service.dart';
import '../../data/remote/image_download_service.dart';
import '../providers/glucose_provider.dart';
import '../providers/meal_photo_provider.dart';
import '../providers/medicine_provider.dart';
import '../widgets/history_list.dart';

/// 历史记录页面
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime? _selectedDate;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // 页面加载时自动校准同步
    _autoCalibrate();
    // 监听同步服务的数据变化
    CloudSyncService().onDataChanged = () {
      if (mounted) {
        ref.read(glucoseProvider.notifier).loadAll();
        ref.read(mealPhotoProvider.notifier).loadAll();
      }
    };
  }

  @override
  void dispose() {
    CloudSyncService().onDataChanged = null;
    super.dispose();
  }

  /// 自动校准同步（只拉取本地缺少的数据）
  Future<void> _autoCalibrate() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      await CloudSyncService().calibrateAndSync();
    } catch (e) {
      print('自动校准失败：$e');
      // 校准失败不影响使用，只是提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('网络同步失败，显示本地数据'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glucoseState = ref.watch(glucoseProvider);
    final mealState = ref.watch(mealPhotoProvider);
    final glucoseRecords = glucoseState.records;
    final mealRecords = mealState.records;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('历史记录'),
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
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => _showExportOptions(),
            tooltip: '导出数据',
          ),
        ],
      ),
      body: Column(
        children: [
          // 日期筛选
          _buildDateFilter(),
          // 历史记录列表
          Expanded(
            child: HistoryList(
              glucoseRecords: _filterByDate(glucoseRecords),
              mealRecords: _filterByDateMeal(mealRecords),
              onGlucoseTap: (record) => _showRecordDetail(record),
              onMealTap: (record) => _showMealRecordDetail(record),
              onDeleteGlucose: (record) => _confirmDeleteGlucose(record),
              onDeleteMeal: (record) => _confirmDeleteMeal(record),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            const Text(
              '筛选：',
              style: TextStyle(fontSize: AppTheme.textSizeNormal),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('全部', _filterType == '全部'),
                    _filterChip('今日', _filterType == '今日'),
                    _filterChip('本周', _filterType == '本周'),
                    _filterChip('本月', _filterType == '本月'),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: const Text('选择日期'),
                      onPressed: _selectDate,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _filterType = '全部'; // 当前选中的筛选类型

  Widget _filterChip(String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (value) {
          if (value) {
            setState(() {
              _filterType = label;
              _selectedDate = label == '全部'
                  ? null
                  : label == '今日'
                      ? DateTime.now()
                      : null; // 本周/本月时 _selectedDate 为 null，但 _filterType 会记录筛选类型
            });
          }
        },
      ),
    );
  }

  List<BloodGlucoseRecord> _filterByDate(List<BloodGlucoseRecord> records) {
    // 全部：不过滤
    if (_filterType == '全部') return records;

    // 今日：按 _selectedDate 精确匹配
    if (_filterType == '今日' && _selectedDate != null) {
      final selected = _selectedDate!;
      return records.where((record) {
        return record.timestamp.year == selected.year &&
            record.timestamp.month == selected.month &&
            record.timestamp.day == selected.day;
      }).toList();
    }

    // 本周
    if (_filterType == '本周') {
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      return records.where((record) {
        return record.timestamp.isAfter(weekStart.subtract(const Duration(days: 1)));
      }).toList();
    }

    // 本月
    if (_filterType == '本月') {
      final now = DateTime.now();
      return records.where((record) {
        return record.timestamp.year == now.year &&
            record.timestamp.month == now.month;
      }).toList();
    }

    // 自定义日期
    if (_selectedDate != null) {
      final selected = _selectedDate!;
      return records.where((record) {
        return record.timestamp.year == selected.year &&
            record.timestamp.month == selected.month &&
            record.timestamp.day == selected.day;
      }).toList();
    }

    return records;
  }

  List<MealPhotoRecord> _filterByDateMeal(List<MealPhotoRecord> records) {
    // 全部：不过滤
    if (_filterType == '全部') return records;

    // 今日：按 _selectedDate 精确匹配
    if (_filterType == '今日' && _selectedDate != null) {
      final selected = _selectedDate!;
      return records.where((record) {
        return record.timestamp.year == selected.year &&
            record.timestamp.month == selected.month &&
            record.timestamp.day == selected.day;
      }).toList();
    }

    // 本周
    if (_filterType == '本周') {
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      return records.where((record) {
        return record.timestamp.isAfter(weekStart.subtract(const Duration(days: 1)));
      }).toList();
    }

    // 本月
    if (_filterType == '本月') {
      final now = DateTime.now();
      return records.where((record) {
        return record.timestamp.year == now.year &&
            record.timestamp.month == now.month;
      }).toList();
    }

    // 自定义日期
    if (_selectedDate != null) {
      final selected = _selectedDate!;
      return records.where((record) {
        return record.timestamp.year == selected.year &&
            record.timestamp.month == selected.month &&
            record.timestamp.day == selected.day;
      }).toList();
    }

    return records;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  bool _isToday (DateTime? date) {
    if (_filterType != '今日') return false;
    return true;
  }

  bool _isThisWeek(DateTime? date) {
    if (_filterType != '本周') return false;
    return true;
  }

  bool _isThisMonth(DateTime? date) {
    if (_filterType != '本月') return false;
    return true;
  }

  void _showRecordDetail(BloodGlucoseRecord record) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300]!,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '血糖记录',
                  style: TextStyle(
                    fontSize: AppTheme.textSizeLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '${record.value}',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getGlucoseColor(record.value),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'mmol/L',
                style: const TextStyle(
                  fontSize: AppTheme.textSizeNormal,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('测量时间：${record.timestamp}'),
            Text('时段：${getPeriodName(record.period)}'),
            if (record.note != null && record.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('备注：${record.note}'),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除记录'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () => _confirmDeleteGlucose(record),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 删除血糖记录（从列表长按或删除按钮调用）
  Future<void> _confirmDeleteGlucose(BloodGlucoseRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条血糖记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(glucoseProvider.notifier).deleteRecord(record.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已删除血糖记录')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败：$e')),
          );
        }
      }
    }
  }

  void _showMealRecordDetail(MealPhotoRecord record) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _MealRecordDetailSheet(
        record: record,
        onMarkMedicineTaken: () {
          _markMealMedicineTaken(record);
          Navigator.pop(context);
        },
        onDelete: () => _confirmDeleteMealFromDetail(record, context),
        onShowFullScreen: _showFullScreenImage,
      ),
    );
  }
}

/// 饮食记录详情弹窗（支持进度显示）
class _MealRecordDetailSheet extends StatefulWidget {
  final MealPhotoRecord record;
  final VoidCallback onMarkMedicineTaken;
  final VoidCallback onDelete;
  final Function(String) onShowFullScreen;

  const _MealRecordDetailSheet({
    required this.record,
    required this.onMarkMedicineTaken,
    required this.onDelete,
    required this.onShowFullScreen,
  });

  @override
  State<_MealRecordDetailSheet> createState() => _MealRecordDetailSheetState();
}

class _MealRecordDetailSheetState extends State<_MealRecordDetailSheet> {
  String? _localImagePath;
  bool _isDownloading = false;
  int _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadImagePath();
  }

  Future<void> _loadImagePath() async {
    if (widget.record.imagePath.startsWith('/images/')) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0;
      });

      try {
        // 先检查本地缓存
        _localImagePath = await ImageDownloadService.getLocalImagePath(widget.record.id);

        if (_localImagePath == null) {
          // 下载图片
          _localImagePath = await ImageDownloadService.downloadImage(
            widget.record.id,
            widget.record.imagePath,
            onProgress: (progress) {
              if (mounted) {
                setState(() => _downloadProgress = progress);
              }
            },
          );
        }
      } catch (e) {
        print('获取图片失败：$e');
      } finally {
        if (mounted) {
          setState(() => _isDownloading = false);
        }
      }
    } else {
      _localImagePath = widget.record.imagePath;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealType = widget.record.mealType;
    final color = _getMealTypeColor(mealType);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300]!,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${getMealTypeName(mealType)}饮食记录',
                style: const TextStyle(
                  fontSize: AppTheme.textSizeLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 显示图片 - 点击可放大
          Center(
            child: GestureDetector(
              onTap: () {
                if (_localImagePath != null && _localImagePath!.isNotEmpty) {
                  widget.onShowFullScreen(_localImagePath!);
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _localImagePath != null && _localImagePath!.isNotEmpty
                    ? Image.file(
                        File(_localImagePath!),
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 64),
                          );
                        },
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            color: Colors.grey[300],
                          ),
                          if (_isDownloading) ...[
                            SizedBox(
                              width: 200,
                              height: 200,
                              child: CircularProgressIndicator(
                                value: _downloadProgress > 0 ? _downloadProgress / 100 : null,
                                strokeWidth: 3,
                              ),
                            ),
                            Positioned(
                              child: Text(
                                '$_downloadProgress%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ] else ...[
                            const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 8),
                                Text('准备下载...'),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.zoom_out_map, size: 18),
              label: const Text('点击查看大图'),
              onPressed: _localImagePath != null && _localImagePath!.isNotEmpty
                  ? () => widget.onShowFullScreen(_localImagePath!)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text('拍照时间：${widget.record.timestamp}'),
          Text('餐型：${getMealTypeName(mealType)}'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('吃药状态：'),
              if (widget.record.medicineTaken)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '已吃药',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: widget.onMarkMedicineTaken,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('标记吃药'),
                ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除记录'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: widget.onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

Color _getMealTypeColor(MealType mealType) {
  switch (mealType) {
    case MealType.breakfast:
      return Colors.orange;
    case MealType.lunch:
      return Colors.green;
    case MealType.dinner:
      return Colors.blue;
    case MealType.snack:
      return Colors.purple;
  }
}

extension on _HistoryScreenState {
  Future<void> _confirmDeleteMealFromDetail(MealPhotoRecord record, BuildContext sheetContext) async {
    // 先关闭 BottomSheet
    Navigator.pop(sheetContext);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条饮食记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(mealPhotoProvider.notifier).deleteRecord(record.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除饮食记录')),
        );
      }
    }
  }

  Future<void> _confirmDeleteMeal(MealPhotoRecord record) async {
    // 关闭长按删除时的确认对话框，不关闭 BottomSheet
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条饮食记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(mealPhotoProvider.notifier).deleteRecord(record.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除饮食记录')),
        );
      }
    }
  }

  Future<void> _markMealMedicineTaken(MealPhotoRecord record) async {
    // 标记已吃药
    await ref.read(mealPhotoProvider.notifier).markMedicineTaken(record.id);

    // 减少药品库存（一次吃一片）
    await ref.read(medicineProvider.notifier).recordTaken(1);

    if (mounted) {
      Navigator.pop(context); // 关闭详情弹窗
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已记录吃药，请继续保持！'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showFullScreenImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description, size: 32),
              title: const Text('导出为 CSV', style: TextStyle(fontSize: 18)),
              subtitle: const Text('适合用 Excel 打开'),
              onTap: () => _exportCsv(),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, size: 32),
              title: const Text('导出为 PDF', style: TextStyle(fontSize: 18)),
              subtitle: const Text('生成健康报告'),
              onTap: () => _exportPdf(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    Navigator.pop(context);
    try {
      final filePath = await ExportService.exportToCsv();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV 文件已保存到：$filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出失败，请重试')),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    Navigator.pop(context);
    try {
      final filePath = await ExportService.exportToPdf();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 报告已保存到：$filePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出失败，请重试')),
        );
      }
    }
  }
}
