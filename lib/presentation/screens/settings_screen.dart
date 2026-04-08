import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import '../../config/theme.dart';
import '../../data/local/export_service.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/cloud_api_service.dart';
import '../../data/remote/cloud_sync_service.dart';
import '../providers/glucose_provider.dart';
import '../providers/meal_photo_provider.dart';

/// 设置页面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _measurementReminderEnabled = true;
  bool _medicineReminderEnabled = true;
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 数据管理
          _buildSection(
            title: '数据管理',
            children: [
              _SettingTile(
                icon: Icons.file_download,
                title: '导出数据',
                subtitle: '导出为 CSV 或 PDF 格式',
                onTap: () => _showExportOptions(context),
              ),
              _SettingTile(
                icon: Icons.delete_sweep,
                title: '清空所有数据',
                subtitle: _isClearing ? '正在清空...' : '删除所有本地和云端数据',
                isDestructive: true,
                onTap: _isClearing ? null : () => _confirmClearData(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 提醒设置
          _buildSection(
            title: '提醒设置',
            children: [
              _SettingTile(
                icon: Icons.notifications,
                title: '测量提醒',
                subtitle: '提醒未测量的时段',
                trailing: Switch(
                  value: _measurementReminderEnabled,
                  onChanged: (value) {
                    setState(() => _measurementReminderEnabled = value);
                    HiveService.setValue('measurement_reminder', value);
                  },
                ),
              ),
              _SettingTile(
                icon: Icons.medication,
                title: '吃药提醒',
                subtitle: '饭后 30 分钟提醒吃药',
                trailing: Switch(
                  value: _medicineReminderEnabled,
                  onChanged: (value) {
                    setState(() => _medicineReminderEnabled = value);
                    HiveService.setValue('medicine_reminder', value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 关于
          _buildSection(
            title: '关于',
            children: [
              _SettingTile(
                icon: Icons.info_outline,
                title: '应用版本',
                subtitle: '1.0.0',
              ),
              _SettingTile(
                icon: Icons.help_outline,
                title: '使用帮助',
                subtitle: '如何使用本应用',
                onTap: () => _showHelpDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: AppTheme.textSizeSmall,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  void _showExportOptions(BuildContext context) {
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
              onTap: () => _exportCsv(context),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, size: 32),
              title: const Text('导出为 PDF', style: TextStyle(fontSize: 18)),
              subtitle: const Text('生成健康报告'),
              onTap: () => _exportPdf(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    Navigator.pop(context);
    try {
      final filePath = await ExportService.exportToCsv();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV 文件已保存到：$filePath'),
            duration: const Duration(seconds: 5),
          ),
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

  Future<void> _exportPdf(BuildContext context) async {
    Navigator.pop(context);
    try {
      final filePath = await ExportService.exportToPdf();
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (format) async {
            final file = File(filePath);
            return await file.readAsBytes();
          },
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

  /// 清空所有数据（本地 + 云端）
  Future<void> _confirmClearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空数据'),
        content: const Text(
          '确定要删除所有本地和云端的血糖、饮食记录吗？此操作不可恢复！',
          style: TextStyle(fontSize: AppTheme.textSizeNormal),
        ),
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
            child: const Text('确认清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isClearing = true);

      try {
        // 1. 获取所有本地记录 ID
        final glucoseIds = HiveService.allGlucoseRecords.map((r) => r.id).toList();
        final mealIds = HiveService.allMealRecords.map((r) => r.id).toList();

        // 2. 先删除云端数据（异步并行执行）
        final api = CloudApiService();
        final deleteFutures = <Future>[];

        for (final id in glucoseIds) {
          deleteFutures.add(api.deleteGlucoseRecord(id).catchError((e) {
            print('删除云端血糖记录失败 $id: $e');
          }));
        }

        for (final id in mealIds) {
          deleteFutures.add(api.deleteMealRecord(id).catchError((e) {
            print('删除云端饮食记录失败 $id: $e');
          }));
        }

        // 等待所有删除完成
        if (deleteFutures.isNotEmpty) {
          await Future.wait(deleteFutures);
        }

        // 3. 清空本地数据
        await HiveService.clearAllGlucoseRecords();
        await HiveService.clearAllMealRecords();
        await HiveService.clearAllMedicationRecords();

        // 4. 通知 Provider 刷新
        if (mounted) {
          ref.read(glucoseProvider.notifier).loadAll();
          ref.read(mealPhotoProvider.notifier).loadAll();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('所有数据已清空（本地 + 云端）'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清空失败：$e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isClearing = false);
        }
      }
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用帮助'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '如何记录血糖？',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('1. 在首页点击任意时段卡片\n2. 输入血糖值\n3. 选择测量时段\n4. 添加备注（可选）\n5. 点击保存'),
              SizedBox(height: 16),
              Text(
                '如何记录饮食？',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('1. 在首页点击"记录饮食"按钮\n2. 选择餐型（早餐/午餐/晚餐）\n3. 拍照或从相册选择\n4. 系统会在饭后 30 分钟提醒您吃药'),
              SizedBox(height: 16),
              Text(
                '如何查看历史数据？',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('点击底部导航栏的"历史"标签，可以查看所有历史记录。支持按日期筛选和导出数据。'),
              SizedBox(height: 16),
              Text(
                '血糖参考值',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• 空腹：3.9-6.1 mmol/L\n• 餐后 2 小时：<7.8 mmol/L\n• 睡前：5.6-7.8 mmol/L'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : AppTheme.primaryColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
