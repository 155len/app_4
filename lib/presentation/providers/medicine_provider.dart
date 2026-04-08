import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/hive_service.dart';

/// 药品状态
class MedicineState {
  final String name;
  final int totalStock;  // 药品总数
  final int timesPerDay;  // 一天几次
  final int pillsPerTime;  // 一次几片
  final int remainingDays;  // 剩余天数
  final bool isLow;  // 是否余量不足

  MedicineState({
    this.name = '降糖药',
    this.totalStock = 0,
    this.timesPerDay = 3,
    this.pillsPerTime = 1,
    this.remainingDays = 0,
    this.isLow = false,
  });

  /// 计算每日消耗量
  int get dailyConsumption => timesPerDay * pillsPerTime;

  /// 计算剩余天数
  int calculateRemainingDays() {
    if (dailyConsumption == 0) return 0;
    return totalStock ~/ dailyConsumption;
  }

  /// 检查是否需要补充（剩余不足 7 天）
  bool checkIsLow() {
    return remainingDays < 7;
  }

  MedicineState copyWith({
    String? name,
    int? totalStock,
    int? timesPerDay,
    int? pillsPerTime,
    int? remainingDays,
    bool? isLow,
  }) {
    return MedicineState(
      name: name ?? this.name,
      totalStock: totalStock ?? this.totalStock,
      timesPerDay: timesPerDay ?? this.timesPerDay,
      pillsPerTime: pillsPerTime ?? this.pillsPerTime,
      remainingDays: remainingDays ?? this.remainingDays,
      isLow: isLow ?? this.isLow,
    );
  }
}

/// 药品 Provider
final medicineProvider = StateNotifierProvider<MedicineNotifier, MedicineState>((ref) {
  return MedicineNotifier();
});

class MedicineNotifier extends StateNotifier<MedicineState> {
  MedicineNotifier() : super(MedicineState()) {
    loadSettings();
  }

  /// 加载设置
  Future<void> loadSettings() async {
    final name = HiveService.getValue('medicine_name', '降糖药');
    final totalStock = HiveService.getValue('medicine_total', 0);
    final timesPerDay = HiveService.getValue('medicine_times', 3);
    final pillsPerTime = HiveService.getValue('medicine_pills', 1);

    final remainingDays = totalStock ~/ (timesPerDay * pillsPerTime);
    final isLow = remainingDays < 7;

    state = MedicineState(
      name: name,
      totalStock: totalStock,
      timesPerDay: timesPerDay,
      pillsPerTime: pillsPerTime,
      remainingDays: remainingDays,
      isLow: isLow,
    );
  }

  /// 更新药品设置
  Future<void> updateSettings({
    String? name,
    int? totalStock,
    int? timesPerDay,
    int? pillsPerTime,
  }) async {
    final newName = name ?? state.name;
    final newTotal = totalStock ?? state.totalStock;
    final newTimes = timesPerDay ?? state.timesPerDay;
    final newPills = pillsPerTime ?? state.pillsPerTime;

    await HiveService.setValue('medicine_name', newName);
    await HiveService.setValue('medicine_total', newTotal);
    await HiveService.setValue('medicine_times', newTimes);
    await HiveService.setValue('medicine_pills', newPills);

    final remainingDays = newTotal ~/ (newTimes * newPills);
    final isLow = remainingDays < 7;

    state = state.copyWith(
      name: newName,
      totalStock: newTotal,
      timesPerDay: newTimes,
      pillsPerTime: newPills,
      remainingDays: remainingDays,
      isLow: isLow,
    );
  }

  /// 记录吃药
  Future<void> recordTaken(int count) async {
    final newTotal = state.totalStock - count;
    if (newTotal < 0) return;

    await HiveService.setValue('medicine_total', newTotal);

    final remainingDays = newTotal ~/ state.dailyConsumption;
    final isLow = remainingDays < 7;

    state = state.copyWith(
      totalStock: newTotal,
      remainingDays: remainingDays,
      isLow: isLow,
    );
  }

  /// 补充药品
  Future<void> addStock(int count) async {
    final newTotal = state.totalStock + count;
    await HiveService.setValue('medicine_total', newTotal);

    final remainingDays = newTotal ~/ state.dailyConsumption;
    final isLow = remainingDays < 7;

    state = state.copyWith(
      totalStock: newTotal,
      remainingDays: remainingDays,
      isLow: isLow,
    );
  }

  /// 重置药品
  Future<void> resetStock(int newTotal) async {
    await HiveService.setValue('medicine_total', newTotal);

    final remainingDays = newTotal ~/ state.dailyConsumption;
    final isLow = remainingDays < 7;

    state = state.copyWith(
      totalStock: newTotal,
      remainingDays: remainingDays,
      isLow: isLow,
    );
  }
}
