import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/time_period.dart';
import '../../config/theme.dart';

/// 血糖输入组件 - 用于输入血糖值
class GlucoseInput extends StatefulWidget {
  final double? initialValue;
  final ValueChanged<double> onValueChange;
  final bool autofocus;

  const GlucoseInput({
    super.key,
    this.initialValue,
    required this.onValueChange,
    this.autofocus = false,
  });

  @override
  State<GlucoseInput> createState() => _GlucoseInputState();
}

class _GlucoseInputState extends State<GlucoseInput> {
  late TextEditingController _controller;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validateAndNotify(String value) {
    if (value.isEmpty) {
      setState(() => _errorText = '请输入血糖值');
      return;
    }

    final numValue = double.tryParse(value);
    if (numValue == null) {
      setState(() => _errorText = '请输入有效数字');
      return;
    }

    if (numValue < 1 || numValue > 30) {
      setState(() => _errorText = '血糖值应在 1-30 mmol/L 之间');
      return;
    }

    setState(() => _errorText = '');
    widget.onValueChange(numValue);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '血糖值 (mmol/L)',
          style: TextStyle(
            fontSize: AppTheme.textSizeNormal,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          autofocus: widget.autofocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
          ],
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '--',
            hintStyle: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
            suffixText: 'mmol/L',
            suffixStyle: const TextStyle(
              fontSize: AppTheme.textSizeNormal,
              color: Colors.grey,
            ),
            errorText: _errorText.isEmpty ? null : _errorText,
          ),
          onChanged: _validateAndNotify,
        ),
      ],
    );
  }
}

/// 时段选择器组件
class PeriodSelector extends StatelessWidget {
  final TimePeriod selectedPeriod;
  final ValueChanged<TimePeriod> onPeriodChange;
  final bool showAllPeriods;

  const PeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChange,
    this.showAllPeriods = true,
  });

  @override
  Widget build(BuildContext context) {
    final periods = showAllPeriods
        ? TimePeriod.values
        : [
            TimePeriod.fasting,
            TimePeriod.beforeBreakfast,
            TimePeriod.afterBreakfast,
            TimePeriod.beforeLunch,
            TimePeriod.afterLunch,
            TimePeriod.beforeDinner,
            TimePeriod.afterDinner,
            TimePeriod.bedtime,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '测量时段',
          style: TextStyle(
            fontSize: AppTheme.textSizeNormal,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: periods.map((period) {
            final isSelected = period == selectedPeriod;
            return ChoiceChip(
              label: Text(getPeriodName(period, short: true)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onPeriodChange(period);
                }
              },
              selectedColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: AppTheme.textSizeSmall,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// 备注输入组件
class NoteInput extends StatelessWidget {
  final String? note;
  final ValueChanged<String?> onNoteChange;

  const NoteInput({
    super.key,
    this.note,
    required this.onNoteChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '备注（可选）',
          style: TextStyle(
            fontSize: AppTheme.textSizeNormal,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: '例如：运动后、服药后等',
          ),
          maxLines: 2,
          onChanged: onNoteChange,
        ),
      ],
    );
  }
}
