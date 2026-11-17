import '../../data/models/activity_level.dart';
import '../../data/models/gender.dart';
import '../../data/models/goal.dart';

/// Результат расчёта нормы
class NutritionResult {
  final int bmr; // базовый обмен
  final int maintenanceKcal; // норма для поддержания веса
  final int targetKcal; // норма с учётом цели
  final int protein; // граммы
  final int fat;
  final int carbs;
  final int? weeks; // прогноз срока достижения цели

  const NutritionResult({
    required this.bmr,
    required this.maintenanceKcal,
    required this.targetKcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.weeks,
  });
}

class NutritionCalculator {
  static const double _kcalPerKg = 7700; // ккал в 1 кг жировой ткани

  static NutritionResult calculate({
    required Gender gender,
    required int age,
    required int heightCm,
    required double weightKg,
    required double targetWeightKg,
    required ActivityLevel activity,
    required Goal goal,
  }) {
    // 1. Базовый обмен (формула Миффлина-Сан Жеора)
    final bmr = 10 * weightKg +
        6.25 * heightCm -
        5 * age +
        (gender == Gender.male ? 5 : -161);

    // 2. Суточная норма для поддержания веса
    final maintenance = bmr * activity.factor;

    // 3. Поправка на цель
    double target = switch (goal) {
      Goal.lose => maintenance * 0.85, // дефицит 15%
      Goal.maintain => maintenance,
      Goal.gain => maintenance * 1.12, // профицит 12%
    };

    // Нижняя граница, чтобы не уйти в опасно низкую калорийность
    final minKcal = gender == Gender.male ? 1500.0 : 1200.0;
    if (goal == Goal.lose && target < minKcal) target = minKcal;

    final targetKcal = target.round();

    // 4. БЖУ: белок от веса, жиры 25% калорий, углеводы остаток
    final proteinPerKg = switch (goal) {
      Goal.lose => 2.0,
      Goal.maintain => 1.6,
      Goal.gain => 1.8,
    };
    final protein = (weightKg * proteinPerKg).round();
    final fat = (targetKcal * 0.25 / 9).round();
    var carbs = ((targetKcal - protein * 4 - fat * 9) / 4).round();
    if (carbs < 0) carbs = 0;

    // 5. Прогноз срока
    int? weeks;
    if (goal != Goal.maintain) {
      final dailyDiff = (maintenance - targetKcal).abs();
      final kgDiff = (targetWeightKg - weightKg).abs();
      if (dailyDiff > 0 && kgDiff > 0) {
        weeks = (kgDiff * _kcalPerKg / (dailyDiff * 7)).ceil();
      }
    }

    return NutritionResult(
      bmr: bmr.round(),
      maintenanceKcal: maintenance.round(),
      targetKcal: targetKcal,
      protein: protein,
      fat: fat,
      carbs: carbs,
      weeks: weeks,
    );
  }
}