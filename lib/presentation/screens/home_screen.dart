import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../data/models/meal_photo.dart';
import '../../domain/entities/meal_type.dart';
import '../providers/glucose_provider.dart';
import '../providers/meal_photo_provider.dart';
import '../providers/medicine_provider.dart';
import 'add_glucose_screen.dart';
import 'history_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'medicine_screen.dart';

/// 首页 - 简化为拍照和记录两个大模块
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final glucoseState = ref.watch(glucoseProvider);
    final medicineState = ref.watch(medicineProvider);

    // 页面列表
    final pages = [
      _HomeTab(
        todayGlucoseCount: glucoseState.todayRecords.length,
        todayMealCount: ref.watch(mealPhotoProvider).todayRecords.length,
        medicineRemaining: medicineState.remainingDays,
        medicineLow: medicineState.isLow,
        onAddGlucose: () => _navigateToAddGlucose(),
        onTakePhoto: () => _navigateToTakePhoto(),
        onMedicineTap: () => _navigateToMedicine(),
        onRefresh: () => _refreshHomeData(),
        isRefreshing: _isRefreshing,
      ),
      const HistoryScreen(),
      const StatsScreen(),
      const MedicineScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() => _selectedIndex = index);
              // 切换到首页时刷新数据
              if (index == 0) {
                ref.read(glucoseProvider.notifier).refreshToday();
                ref.read(mealPhotoProvider.notifier).refreshReminders();
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppTheme.primaryColor,
            unselectedItemColor: Colors.grey,
            selectedFontSize: 14,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, size: 28),
                activeIcon: Icon(Icons.home, size: 28),
                label: '首页',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_outlined, size: 28),
                activeIcon: Icon(Icons.history, size: 28),
                label: '历史',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined, size: 28),
                activeIcon: Icon(Icons.bar_chart, size: 28),
                label: '统计',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.medication_outlined, size: 28),
                activeIcon: Icon(Icons.medication, size: 28),
                label: '药品',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined, size: 28),
                activeIcon: Icon(Icons.settings, size: 28),
                label: '设置',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToAddGlucose() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddGlucoseScreen(),
      ),
    );

    if (result == true && mounted) {
      ref.read(glucoseProvider.notifier).refreshToday();
      _showSuccessSnack('血糖记录成功');
    }
  }

  Future<void> _navigateToTakePhoto() async {
    // 直接显示拍照选项
    _showMealPhotoOptions();
  }

  void _showMealPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '选择餐型',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MealTypeButton(
                    icon: Icons.free_breakfast,
                    label: '早餐',
                    color: Colors.orange,
                    onTap: () => _takeMealPhoto(MealType.breakfast),
                  ),
                  _MealTypeButton(
                    icon: Icons.lunch_dining,
                    label: '午餐',
                    color: Colors.green,
                    onTap: () => _takeMealPhoto(MealType.lunch),
                  ),
                  _MealTypeButton(
                    icon: Icons.dinner_dining,
                    label: '晚餐',
                    color: Colors.blue,
                    onTap: () => _takeMealPhoto(MealType.dinner),
                  ),
                  _MealTypeButton(
                    icon: Icons.cookie,
                    label: '加餐',
                    color: Colors.purple,
                    onTap: () => _takeMealPhoto(MealType.snack),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '拍照后将在 30 分钟内提醒吃药',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _takeMealPhoto(MealType mealType) async {
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 300));

    final notifier = ref.read(mealPhotoProvider.notifier);
    final record = await notifier.takePhoto(mealType);

    if (record != null && mounted) {
      // 立即显示吃药提醒
      _showMedicineReminder(mealType, record);
    }
  }

  void _showMedicineReminder(MealType mealType, MealPhotoRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.medication, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text(
              '吃药提醒',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          '您已记录${getMealTypeName(mealType)}，请及时服用降糖药！\n\n系统将在 30 分钟后再次提醒您。',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '稍后提醒',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markMedicineTaken(record);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              '已吃药',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markMedicineTaken(MealPhotoRecord record) async {
    // 标记已吃药
    await ref.read(mealPhotoProvider.notifier).markMedicineTaken(record.id);

    // 减少药品库存（一次吃一片）
    await ref.read(medicineProvider.notifier).recordTaken(1);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已记录吃药，请继续保持！'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToMedicine() {
    setState(() => _selectedIndex = 3);
  }

  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _refreshHomeData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await ref.read(glucoseProvider.notifier).refreshToday();
      await ref.read(mealPhotoProvider.notifier).refreshReminders();
      if (mounted) {
        _showSuccessSnack('数据已刷新');
      }
    } catch (e) {
      print('刷新失败：$e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }
}

String getMealTypeName(MealType mealType) {
  switch (mealType) {
    case MealType.breakfast:
      return '早餐';
    case MealType.lunch:
      return '午餐';
    case MealType.dinner:
      return '晚餐';
    case MealType.snack:
      return '加餐';
  }
}

class _MealTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MealTypeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 36,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 首页标签页内容 - 简化为两个大模块
class _HomeTab extends StatelessWidget {
  final int todayGlucoseCount;
  final int todayMealCount;
  final int medicineRemaining;
  final bool medicineLow;
  final VoidCallback onAddGlucose;
  final VoidCallback onTakePhoto;
  final VoidCallback onMedicineTap;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  const _HomeTab({
    required this.todayGlucoseCount,
    required this.todayMealCount,
    required this.medicineRemaining,
    required this.medicineLow,
    required this.onAddGlucose,
    required this.onTakePhoto,
    required this.onMedicineTap,
    required this.onRefresh,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.year}年${now.month}月${now.day}日 '
        '${['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'][now.weekday - 1]}';
    final period = getGreeting();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
            Colors.white,
          ],
          stops: const [0, 0.35, 0.35],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 头部
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        period,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white70,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isRefreshing ? Icons.refresh : Icons.refresh,
                          color: Colors.white,
                        ),
                        onPressed: isRefreshing ? null : onRefresh,
                        tooltip: '刷新数据',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // 主体内容
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 两大功能模块
                    Row(
                      children: [
                        Expanded(
                          child: _FunctionCard(
                            icon: Icons.edit,
                            iconColor: Colors.blue,
                            title: '记录血糖',
                            subtitle: '$todayGlucoseCount 次今日',
                            onTap: onAddGlucose,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _FunctionCard(
                            icon: Icons.camera_alt,
                            iconColor: Colors.orange,
                            title: '拍照记录',
                            subtitle: '$todayMealCount 次今日',
                            onTap: onTakePhoto,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 药品余量卡片
                    GestureDetector(
                      onTap: onMedicineTap,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: medicineLow
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.medication,
                                color: medicineLow ? Colors.red : Colors.green,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '药品余量',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '$medicineRemaining 天',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: medicineLow
                                              ? Colors.red
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (medicineLow)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            '需补充',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 28,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 提示卡片
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue[200]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '拍照记录饮食后，系统会在 30 分钟内提醒您吃药',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
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

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 11) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    if (hour < 22) return '晚上好';
    return '夜深了';
  }
}

class _FunctionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FunctionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
