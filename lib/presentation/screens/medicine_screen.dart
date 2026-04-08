import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../providers/medicine_provider.dart';

/// 药品管理页面
class MedicineScreen extends ConsumerStatefulWidget {
  const MedicineScreen({super.key});

  @override
  ConsumerState<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends ConsumerState<MedicineScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(medicineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('药品管理'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 药品余量卡片
          _buildRemainingCard(state),
          const SizedBox(height: 16),
          // 药品信息卡片
          _buildInfoCard(state),
          const SizedBox(height: 16),
          // 操作按钮
          _buildActionButtons(state),
          const SizedBox(height: 16),
          // 设置卡片
          _buildSettingsCard(state),
        ],
      ),
    );
  }

  Widget _buildRemainingCard(MedicineState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: state.isLow
              ? [Colors.red[300]!, Colors.red[500]!]
              : [Colors.green[300]!, Colors.green[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (state.isLow ? Colors.red : Colors.green).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            state.isLow ? Icons.warning : Icons.check_circle,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            state.isLow ? '药品不足' : '药品充足',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '剩余 ${state.remainingDays} 天用量',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '库存：',
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.white70,
                ),
              ),
              Text(
                '${state.totalStock}',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                ' 片',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(MedicineState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '药品信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(label: '药品名称', value: state.name),
            const Divider(),
            _InfoRow(label: '每天次数', value: '${state.timesPerDay} 次'),
            const Divider(),
            _InfoRow(label: '每次用量', value: '${state.pillsPerTime} 片'),
            const Divider(),
            _InfoRow(label: '每日消耗', value: '${state.dailyConsumption} 片'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(MedicineState state) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.remove),
            label: const Text('记录吃药'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              foregroundColor: AppTheme.primaryColor,
            ),
            onPressed: () => _showRecordDialog(state),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('补充药品'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showAddStockDialog(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(MedicineState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  '药品设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('修改药品设置'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: () => _showSettingsDialog(state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordDialog(MedicineState state) {
    int selectedCount = state.pillsPerTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('记录吃药'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('本次服用了多少片？'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [1, 2, 3, 4, 5, 6].map((count) {
                  final isSelected = count == selectedCount;
                  return ChoiceChip(
                    label: Text('$count 片'),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => selectedCount = count);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(medicineProvider.notifier).recordTaken(selectedCount);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已记录吃药')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStockDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('补充药品'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('输入补充的药品数量：'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '数量',
                prefixIcon: Icon(Icons.medication),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final count = int.tryParse(controller.text);
              if (count != null && count > 0) {
                ref.read(medicineProvider.notifier).addStock(count);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已补充 $count 片药品')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(MedicineState state) {
    final nameController = TextEditingController(text: state.name);
    int timesPerDay = state.timesPerDay;
    int pillsPerTime = state.pillsPerTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('药品设置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '药品名称',
                    prefixIcon: Icon(Icons.medication),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('每天几次？'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [1, 2, 3, 4].map((count) {
                    final isSelected = count == timesPerDay;
                    return ChoiceChip(
                      label: Text('$count 次'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => timesPerDay = count);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('每次几片？'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [1, 2, 3, 4, 5].map((count) {
                    final isSelected = count == pillsPerTime;
                    return ChoiceChip(
                      label: Text('$count 片'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => pillsPerTime = count);
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(medicineProvider.notifier).updateSettings(
                  name: nameController.text,
                  timesPerDay: timesPerDay,
                  pillsPerTime: pillsPerTime,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('设置已保存')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
