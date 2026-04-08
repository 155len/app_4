import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/blood_glucose.dart';
import '../../data/models/meal_photo.dart';
import '../../config/theme.dart';
import '../../utils/date_utils.dart' as date_util;
import '../../domain/entities/time_period.dart';
import '../../data/remote/image_download_service.dart';
import '../../domain/entities/meal_type.dart';

/// 历史记录列表组件
class HistoryList extends StatelessWidget {
  final List<BloodGlucoseRecord> glucoseRecords;
  final List<MealPhotoRecord> mealRecords;
  final Function(BloodGlucoseRecord)? onGlucoseTap;
  final Function(MealPhotoRecord)? onMealTap;
  final Function(BloodGlucoseRecord)? onDeleteGlucose;
  final Function(MealPhotoRecord)? onDeleteMeal;

  const HistoryList({
    super.key,
    required this.glucoseRecords,
    required this.mealRecords,
    this.onGlucoseTap,
    this.onMealTap,
    this.onDeleteGlucose,
    this.onDeleteMeal,
  });

  @override
  Widget build(BuildContext context) {
    // 合并所有记录并按日期分组
    final allRecords = <_RecordItem>[];

    for (final record in glucoseRecords) {
      allRecords.add(_RecordItem(
        timestamp: record.timestamp,
        type: _RecordType.glucose,
        glucoseRecord: record,
      ));
    }

    for (final record in mealRecords) {
      allRecords.add(_RecordItem(
        timestamp: record.timestamp,
        type: _RecordType.meal,
        mealRecord: record,
      ));
    }

    // 按时间倒序排序
    allRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (allRecords.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '暂无历史记录',
            style: TextStyle(
              fontSize: AppTheme.textSizeNormal,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    // 按日期分组
    final groupedRecords = <String, List<_RecordItem>>{};
    for (final record in allRecords) {
      final dateKey = date_util.DateUtils.formatDate(record.timestamp, showYear: true);
      groupedRecords.putIfAbsent(dateKey, () => []).add(record);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedRecords.length,
      itemBuilder: (context, index) {
        final dateKey = groupedRecords.keys.elementAt(index);
        final dateRecords = groupedRecords[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期标题
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: AppTheme.textSizeLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 该日期的记录
            ...dateRecords.map((record) {
              if (record.type == _RecordType.glucose) {
                return _GlucoseTile(
                  record: record.glucoseRecord!,
                  onTap: () => onGlucoseTap?.call(record.glucoseRecord!),
                  onDelete: () => onDeleteGlucose?.call(record.glucoseRecord!),
                );
              } else {
                return _MealTile(
                  record: record.mealRecord!,
                  onTap: () => onMealTap?.call(record.mealRecord!),
                  onDelete: () => onDeleteMeal?.call(record.mealRecord!),
                );
              }
            }),
            const Divider(height: 24),
          ],
        );
      },
    );
  }
}

enum _RecordType { glucose, meal }

class _RecordItem {
  final DateTime timestamp;
  final _RecordType type;
  final BloodGlucoseRecord? glucoseRecord;
  final MealPhotoRecord? mealRecord;

  _RecordItem({
    required this.timestamp,
    required this.type,
    this.glucoseRecord,
    this.mealRecord,
  });
}

class _GlucoseTile extends StatelessWidget {
  final BloodGlucoseRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _GlucoseTile({
    required this.record,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getGlucoseColor(record.value);
    final status = AppTheme.getGlucoseStatus(record.value);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        onLongPress: onDelete,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${record.value}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        title: Text(
          getPeriodName(record.period),
          style: const TextStyle(fontSize: AppTheme.textSizeNormal),
        ),
        subtitle: Text(
          '${DateFormat('HH:mm').format(record.timestamp)} · $status',
          style: const TextStyle(fontSize: AppTheme.textSizeSmall),
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}

class _MealTile extends StatefulWidget {
  final MealPhotoRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _MealTile({
    required this.record,
    this.onTap,
    this.onDelete,
  });

  @override
  State<_MealTile> createState() => _MealTileState();
}

class _MealTileState extends State<_MealTile> {
  String? _localImagePath;
  bool _isDownloading = false;
  int _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadImagePath();
  }

  Future<void> _loadImagePath() async {
    // 尝试获取本地图片路径
    String? path;

    if (widget.record.imagePath.startsWith('/images/')) {
      // 服务器路径，检查本地缓存
      path = await ImageDownloadService.getLocalImagePath(widget.record.id);
      // 如果本地没有，尝试下载
      if (path == null) {
        setState(() {
          _isDownloading = true;
          _downloadProgress = 0;
        });
        try {
          path = await ImageDownloadService.downloadImage(
            widget.record.id,
            widget.record.imagePath,
            onProgress: (progress) {
              if (mounted) {
                setState(() => _downloadProgress = progress);
              }
            },
          );
        } catch (e) {
          print('下载图片失败：$e');
        } finally {
          if (mounted) {
            setState(() => _isDownloading = false);
          }
        }
      }
    } else {
      // 本地路径
      path = widget.record.imagePath;
    }

    if (mounted) {
      setState(() {
        _localImagePath = path;
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealType = widget.record.mealType;
    final color = _getMealTypeColor(mealType);
    final icon = _getMealTypeIcon(mealType);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: widget.onTap,
        onLongPress: widget.onDelete,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _localImagePath != null
              ? Image.file(
                  File(_localImagePath!),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 50,
                      color: color.withOpacity(0.1),
                      child: Icon(icon, color: color, size: 24),
                    );
                  },
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      color: color.withOpacity(0.1),
                    ),
                    if (_isDownloading) ...[
                      // 进度条
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          value: _downloadProgress > 0 ? _downloadProgress / 100 : null,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      // 进度百分比
                      Positioned(
                        child: Text(
                          '$_downloadProgress%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ] else ...[
                      const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
        ),
        title: Text(
          getMealTypeName(mealType),
          style: const TextStyle(fontSize: AppTheme.textSizeNormal),
        ),
        subtitle: Text(
          DateFormat('HH:mm').format(widget.record.timestamp),
          style: const TextStyle(fontSize: AppTheme.textSizeSmall),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.record.medicineTaken)
              Container(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.check_circle, color: Colors.green, size: 20),
              ),
            if (widget.onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: widget.onDelete,
              ),
          ],
        ),
      ),
    );
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

  IconData _getMealTypeIcon(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return Icons.free_breakfast;
      case MealType.lunch:
        return Icons.lunch_dining;
      case MealType.dinner:
        return Icons.dinner_dining;
      case MealType.snack:
        return Icons.cookie;
    }
  }
}
