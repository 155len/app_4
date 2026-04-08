/// 餐型枚举
enum MealType {
  breakfast,  // 早餐
  lunch,      // 午餐
  dinner,     // 晚餐
  snack,      // 加餐
}

/// 获取餐型显示名称
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
