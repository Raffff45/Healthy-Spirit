import 'dart:math';

import 'package:healthy_spirit/data/db/app_database.dart';
import 'package:healthy_spirit/data/models/meal_type.dart';

import '../calculators/food_calculator.dart';

/// Продукт с рассчитанной граммовкой в сгенерированном меню
class GeneratedItem {
  final Product product;
  final double grams;

  const GeneratedItem(this.product, this.grams);

  FoodNutrients get nutrients => FoodNutrients.forGrams(
        kcalPer100: product.kcal,
        proteinPer100: product.protein,
        fatPer100: product.fat,
        carbsPer100: product.carbs,
        grams: grams,
      );
}

/// Один приём пищи
class GeneratedMeal {
  final MealType type;
  final double share; // доля суточной нормы
  final int targetKcal;
  final List<GeneratedItem> items;

  const GeneratedMeal(this.type, this.share, this.targetKcal, this.items);

  FoodNutrients get total => items.fold<FoodNutrients>(
        FoodNutrients.zero,
        (sum, i) => sum + i.nutrients,
      );
}

/// Меню на день
class GeneratedMenu {
  final List<GeneratedMeal> meals;

  const GeneratedMenu(this.meals);

  FoodNutrients get total => meals.fold<FoodNutrients>(
        FoodNutrients.zero,
        (sum, m) => sum + m.total,
      );
}

/// Приём пищи и его доля от суточной нормы
class MealSlot {
  final MealType type;
  final double share;

  const MealSlot(this.type, this.share);
}

// Группы категорий: из какой категории брать продукт на каждое «место» блюда
const _protein = ['Мясо и птица', 'Рыба и морепродукты', 'Бобовые'];
const _meat = ['Мясо и птица', 'Рыба и морепродукты'];
const _grain = ['Крупы и гарниры'];
const _veg = ['Овощи'];
const _fruit = ['Фрукты и ягоды'];
const _dairy = ['Молочные и яйца'];
const _nuts = ['Орехи и семена'];
const _bread = ['Хлеб'];

/// Шаблоны блюд: каждый шаблон это набор «мест», на каждое берётся продукт
const Map<MealType, List<List<List<String>>>> _templates = {
  MealType.breakfast: [
    [_grain, _dairy, _fruit],
    [_dairy, _bread, _veg],
    [_grain, _fruit, _nuts],
    [_dairy, _fruit, _nuts],
  ],
  MealType.lunch: [
    [_protein, _grain, _veg],
    [_meat, _grain, _veg, _veg],
    [_meat, _veg, _bread],
  ],
  MealType.dinner: [
    [_meat, _veg, _grain],
    [_meat, _veg, _veg],
    [_protein, _grain, _veg],
    [_dairy, _veg, _bread],
  ],
  MealType.snack: [
    [_fruit, _nuts],
    [_dairy, _fruit],
    [_bread, _dairy],
    [_fruit, _dairy, _nuts],
    [_nuts],
  ],
};

/// Калорийные «добавки»: берутся, когда калорий в блюде нужно много,
/// а порции основных продуктов ограничены разумным размером
const Map<MealType, List<List<String>>> _extras = {
  MealType.breakfast: [_nuts, _bread, _dairy, _grain],
  MealType.lunch: [_grain, _bread, _dairy],
  MealType.dinner: [_grain, _bread, _dairy],
  MealType.snack: [_nuts, _dairy, _bread],
};

/// Границы порции относительно стандартной (portionG продукта)
const double _minPortionFactor = 0.5;
const double _maxPortionFactor = 1.6;

/// Максимальная разумная масса одного приёма пищи, граммы
const double _maxMealGrams = 700;

/// Генератор меню: случайный подбор с оценкой качества.
///
/// Для каждого приёма пищи делается много попыток:
///  1. выбирается шаблон блюда и случайные продукты под него;
///  2. если калорий нужно много, добавляются калорийные продукты;
///  3. граммовки подгоняются под цель в пределах разумных порций;
///  4. вариант оценивается по отклонению калорий и БЖУ от цели,
///     по отклонению порций от стандартных и по общей массе блюда;
///  5. побеждает вариант с наименьшей оценкой.
class MenuGenerator {
  final Random _rnd;
  static const int attempts = 300;

  MenuGenerator({int? seed}) : _rnd = Random(seed);

  static List<MealSlot> slotsFor(int mealsCount) {
    switch (mealsCount) {
      case 3:
        return const [
          MealSlot(MealType.breakfast, 0.30),
          MealSlot(MealType.lunch, 0.40),
          MealSlot(MealType.dinner, 0.30),
        ];
      case 5:
        return const [
          MealSlot(MealType.breakfast, 0.25),
          MealSlot(MealType.snack, 0.10),
          MealSlot(MealType.lunch, 0.30),
          MealSlot(MealType.snack, 0.10),
          MealSlot(MealType.dinner, 0.25),
        ];
      default:
        return [for (final t in MealType.values) MealSlot(t, t.share)];
    }
  }

  /// Меню на весь день
  GeneratedMenu generateDay({
    required List<Product> products,
    required int dayKcal,
    required int dayProtein,
    required int dayFat,
    required int dayCarbs,
    required int mealsCount,
    Set<int> excludedIds = const {},
  }) {
    final used = <int>{};
    final meals = <GeneratedMeal>[];

    for (final slot in slotsFor(mealsCount)) {
      final meal = generateMeal(
        products: products,
        type: slot.type,
        share: slot.share,
        dayKcal: dayKcal,
        dayProtein: dayProtein,
        dayFat: dayFat,
        dayCarbs: dayCarbs,
        excludedIds: excludedIds,
        usedIds: used,
      );
      // Запоминаем продукты, чтобы в течение дня они меньше повторялись
      used.addAll(meal.items.map((i) => i.product.id));
      meals.add(meal);
    }
    return GeneratedMenu(meals);
  }

  /// Один приём пищи
  GeneratedMeal generateMeal({
    required List<Product> products,
    required MealType type,
    required double share,
    required int dayKcal,
    required int dayProtein,
    required int dayFat,
    required int dayCarbs,
    Set<int> excludedIds = const {},
    Set<int> usedIds = const {},
  }) {
    final targetKcal = dayKcal * share;
    final targetP = dayProtein * share;
    final targetF = dayFat * share;
    final targetC = dayCarbs * share;

    // Подходящие продукты: не исключены и подходят для этого приёма пищи
    final allowed = products
        .where(
          (p) =>
              !excludedIds.contains(p.id) &&
              p.mealTypes.split(',').contains(type.name),
        )
        .toList();

    final templates = _templates[type]!;
    final extras = _extras[type]!;

    // Сколько калорийных добавок нужно: чем больше калорий, тем больше
    final extraCount = ((targetKcal - 450) / 250).floor().clamp(0, 2).toInt();

    List<GeneratedItem>? best;
    var bestScore = double.infinity;

    for (var attempt = 0; attempt < attempts; attempt++) {
      final slots = [...templates[_rnd.nextInt(templates.length)]];
      for (var e = 0; e < extraCount; e++) {
        slots.add(extras[_rnd.nextInt(extras.length)]);
      }

      final chosen = <Product>[];

      for (final categories in slots) {
        var pool = allowed
            .where(
              (p) =>
                  categories.contains(p.category) &&
                  !chosen.any((c) => c.id == p.id),
            )
            .toList();
        if (pool.isEmpty) continue;

        // Сначала берём продукты, которых ещё не было в этот день
        final fresh = pool.where((p) => !usedIds.contains(p.id)).toList();
        if (fresh.isNotEmpty) pool = fresh;

        chosen.add(pool[_rnd.nextInt(pool.length)]);
      }
      if (chosen.isEmpty) continue;

      final items = _fit(chosen, targetKcal);
      final score = _score(items, targetKcal, targetP, targetF, targetC);
      if (score < bestScore) {
        bestScore = score;
        best = items;
      }
    }

    return GeneratedMeal(type, share, targetKcal.round(), best ?? const []);
  }

  /// Подбор граммовок: масштабируем порции под целевые калории,
  /// но не выходим за разумные границы от стандартной порции
  List<GeneratedItem> _fit(List<Product> chosen, double targetKcal) {
    final minG = [
      for (final p in chosen) max(5.0, p.portionG * _minPortionFactor),
    ];
    final maxG = [for (final p in chosen) p.portionG * _maxPortionFactor];

    final grams = [
      for (var i = 0; i < chosen.length; i++)
        (chosen[i].portionG * (0.8 + _rnd.nextDouble() * 0.4))
            .clamp(minG[i], maxG[i])
            .toDouble(),
    ];

    for (var iter = 0; iter < 6; iter++) {
      var total = 0.0;
      for (var i = 0; i < chosen.length; i++) {
        total += chosen[i].kcal * grams[i] / 100;
      }
      if (total <= 0) break;
      final factor = targetKcal / total;
      if ((factor - 1).abs() < 0.01) break;
      for (var i = 0; i < chosen.length; i++) {
        grams[i] = (grams[i] * factor).clamp(minG[i], maxG[i]).toDouble();
      }
    }

    return [
      for (var i = 0; i < chosen.length; i++)
        // Округляем до 5 г, как это делают в реальных рационах
        GeneratedItem(chosen[i], max(5, (grams[i] / 5).round() * 5).toDouble()),
    ];
  }

  /// Чем меньше, тем лучше
  double _score(
    List<GeneratedItem> items,
    double targetKcal,
    double targetP,
    double targetF,
    double targetC,
  ) {
    final t = items.fold<FoodNutrients>(
      FoodNutrients.zero,
      (sum, i) => sum + i.nutrients,
    );
    double err(double value, double target) =>
        target <= 0 ? 0 : (value - target).abs() / target;

    // Отклонение порций от стандартных
    var portionDev = 0.0;
    var totalGrams = 0.0;
    for (final i in items) {
      portionDev += (i.grams / i.product.portionG - 1).abs();
      totalGrams += i.grams;
    }
    portionDev /= items.length;

    // Штраф за слишком тяжёлое блюдо
    final heavy =
        totalGrams > _maxMealGrams ? (totalGrams - _maxMealGrams) / _maxMealGrams : 0.0;

    return 3 * err(t.kcal, targetKcal) +
        err(t.protein, targetP) +
        0.5 * err(t.fat, targetF) +
        0.5 * err(t.carbs, targetC) +
        0.3 * portionDev +
        1.0 * heavy;
  }
}