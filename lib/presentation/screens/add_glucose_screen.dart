import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../domain/entities/time_period.dart';
import '../../data/models/blood_glucose.dart';
import '../providers/glucose_provider.dart';
import '../widgets/glucose_input.dart';

/// 添加血糖记录页面
class AddGlucoseScreen extends ConsumerStatefulWidget {
  const AddGlucoseScreen({super.key});

  @override
  ConsumerState<AddGlucoseScreen> createState() => _AddGlucoseScreenState();
}

class _AddGlucoseScreenState extends ConsumerState<AddGlucoseScreen> {
  final _formKey = GlobalKey<FormState>();

  double? _glucoseValue;
  late TimePeriod _selectedPeriod;
  String? _note;
  bool _isPostMeal = false;

  @override
  void initState() {
    super.initState();
    // 如果没有指定时段，根据当前时间自动判断
    _selectedPeriod = getPeriodFromTime(DateTime.now());
    _isPostMeal = _selectedPeriod == TimePeriod.afterBreakfast ||
        _selectedPeriod == TimePeriod.afterLunch ||
        _selectedPeriod == TimePeriod.afterDinner;
  }

  @override
  Widget build(BuildContext context) {
    final currentPeriodName = getPeriodName(_selectedPeriod);

    return Scaffold(
      appBar: AppBar(
        title: const Text('记录血糖'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 当前时段提示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '当前时段',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          currentPeriodName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 血糖值输入
            GlucoseInput(
              initialValue: _glucoseValue,
              onValueChange: (value) => setState(() => _glucoseValue = value),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            // 时段选择
            PeriodSelector(
              selectedPeriod: _selectedPeriod,
              onPeriodChange: (period) {
                setState(() {
                  _selectedPeriod = period;
                  _isPostMeal = period == TimePeriod.afterBreakfast ||
                      period == TimePeriod.afterLunch ||
                      period == TimePeriod.afterDinner;
                });
              },
            ),
            const SizedBox(height: 24),
            // 备注输入
            NoteInput(
              note: _note,
              onNoteChange: (value) => setState(() => _note = value),
            ),
            const SizedBox(height: 32),
            // 保存按钮
            ElevatedButton(
              onPressed: _saveRecord,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('保存记录', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRecord() async {
    if (_glucoseValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入血糖值')),
      );
      return;
    }

    final record = BloodGlucoseRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      value: _glucoseValue!,
      timestamp: DateTime.now(),
      period: _selectedPeriod,
      note: _note,
      isPostMeal: _isPostMeal,
    );

    await ref.read(glucoseProvider.notifier).addRecord(record);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}
