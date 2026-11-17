/// КБЖУ порции продукта
class FoodNutrients {
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  const FoodNutrients(this.kcal, this.protein, this.fat, this.carbs);

  static const zero = FoodNutrients(0, 0, 0, 0);

  /// Пересчёт с «на 100 г» на нужное количество граммов
  factory FoodNutrients.forGrams({
    required double kcalPer100,
    required double proteinPer100,
    required double fatPer100,
    required double carbsPer100,
    required double grams,
  }) {
    final k = grams / 100;
    return FoodNutrients(
      kcalPer100 * k,
      proteinPer100 * k,
      fatPer100 * k,
      carbsPer100 * k,
    );
  }

  FoodNutrients operator +(FoodNutrients other) => FoodNutrients(
        kcal + other.kcal,
        protein + other.protein,
        fat + other.fat,
        carbs + other.carbs,
      );
}