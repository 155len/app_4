import 'package:flutter/material.dart';

/// 应用主题配置 - 针对老年用户优化
class AppTheme {
  // 主色调 - 蓝色系，清晰舒适
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF63A4FF);
  static const Color primaryDark = Color(0xFF004BA0);

  // 血糖状态颜色
  static const Color glucoseLow = Color(0xFFFFA726);    // 偏低 - 橙色
  static const Color glucoseNormal = Color(0xFF66BB6A); // 正常 - 绿色
  static const Color glucoseHigh = Color(0xFFEF5350);   // 偏高 - 红色

  // 背景色
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;

  // 文字大小 - 适配老年用户
  static const double textSizeSmall = 14.0;
  static const double textSizeNormal = 18.0;
  static const double textSizeLarge = 22.0;
  static const double textSizeXLarge = 28.0;

  // 按钮最小尺寸
  static const double minButtonHeight = 48.0;
  static const double minButtonWidth = 120.0;

  // 圆角
  static const double borderRadius = 12.0;

  /// 获取明亮主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        color: cardBackground,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minButtonWidth, minButtonHeight),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: textSizeNormal,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(minButtonWidth, minButtonHeight),
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontSize: textSizeNormal,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Colors.red),
        ),
        labelStyle: const TextStyle(fontSize: textSizeNormal),
        hintStyle: const TextStyle(
          fontSize: textSizeNormal,
          color: Colors.grey,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        titleTextStyle: const TextStyle(
          fontSize: textSizeLarge,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(fontSize: textSizeNormal),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  /// 获取血糖值对应的颜色
  static Color getGlucoseColor(double value) {
    if (value < 3.9) {
      return glucoseLow;
    } else if (value <= 6.1) {
      return glucoseNormal;
    } else if (value <= 7.8) {
      return glucoseLow;  // 略高，但未到危险程度
    } else {
      return glucoseHigh;
    }
  }

  /// 获取血糖值对应的状态文本
  static String getGlucoseStatus(double value) {
    if (value < 3.9) {
      return '偏低';
    } else if (value <= 6.1) {
      return '正常';
    } else if (value <= 7.8) {
      return '略高';
    } else if (value <= 10.0) {
      return '偏高';
    } else {
      return '过高';
    }
  }

  /// 获取血糖值对应的图标
  static IconData getGlucoseIcon(double value) {
    if (value < 3.9) {
      return Icons.warning_amber_rounded;
    } else if (value <= 7.8) {
      return Icons.check_circle_outline_rounded;
    } else {
      return Icons.warning_rounded;
    }
  }
}
