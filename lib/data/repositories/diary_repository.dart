import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/calculators/food_calculator.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../models/meal_type.dart';

/// Запись дневника вместе с продуктом
class DiaryItem {
  final MealEntry entry;
  final Product product;

  const DiaryItem(this.entry, this.product);

  MealType get mealType => MealType.values.byName(entry.mealType);

  FoodNutrients get nutrients => FoodNutrients.forGrams(
        kcalPer100: product.kcal,
        proteinPer100: product.protein,
        fatPer100: product.fat,
        carbsPer100: product.carbs,
        grams: entry.grams,
      );
}

/// Новая запись для пакетного добавления (например, из генератора)
class NewDiaryEntry {
  final MealType type;
  final int productId;
  final double grams;

  const NewDiaryEntry(this.type, this.productId, this.grams);
}

class DiaryRepository {
  final AppDatabase db;
  DiaryRepository(this.db);

  /// Все записи за день (обновляется автоматически при изменении базы)
  Stream<List<DiaryItem>> watchDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);

    final query = db.select(db.mealEntries).join([
      innerJoin(
        db.products,
        db.products.id.equalsExp(db.mealEntries.productId),
      ),
    ])
      ..where(
        db.mealEntries.date.isBiggerOrEqualValue(start) &
            db.mealEntries.date.isSmallerThanValue(end),
      )
      ..orderBy([OrderingTerm.asc(db.mealEntries.id)]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => DiaryItem(
                  row.readTable(db.mealEntries),
                  row.readTable(db.products),
                ),
              )
              .toList(),
        );
  }

  /// Итоговое КБЖУ по каждому дню (для серий и статистики)
  Stream<Map<DateTime, FoodNutrients>> watchDailyTotals() {
    final query = db.select(db.mealEntries).join([
      innerJoin(
        db.products,
        db.products.id.equalsExp(db.mealEntries.productId),
      ),
    ]);

    return query.watch().map((rows) {
      final map = <DateTime, FoodNutrients>{};
      for (final row in rows) {
        final e = row.readTable(db.mealEntries);
        final p = row.readTable(db.products);
        final day = DateTime(e.date.year, e.date.month, e.date.day);
        final n = FoodNutrients.forGrams(
          kcalPer100: p.kcal,
          proteinPer100: p.protein,
          fatPer100: p.fat,
          carbsPer100: p.carbs,
          grams: e.grams,
        );
        map[day] = (map[day] ?? FoodNutrients.zero) + n;
      }
      return map;
    });
  }

  Future<void> addEntry({
    required DateTime date,
    required MealType type,
    required int productId,
    required double grams,
  }) {
    return db.into(db.mealEntries).insert(
          MealEntriesCompanion.insert(
            date: DateTime(date.year, date.month, date.day, 12),
            mealType: type.name,
            productId: productId,
            grams: grams,
          ),
        );
  }

  /// Добавляет сразу несколько записей одной транзакцией
  Future<void> addEntries(DateTime date, List<NewDiaryEntry> entries) {
    return db.transaction(() async {
      for (final e in entries) {
        await addEntry(
          date: date,
          type: e.type,
          productId: e.productId,
          grams: e.grams,
        );
      }
    });
  }

  Future<void> updateGrams(int id, double grams) {
    return (db.update(db.mealEntries)..where((t) => t.id.equals(id)))
        .write(MealEntriesCompanion(grams: Value(grams)));
  }

  Future<void> deleteEntry(int id) {
    return (db.delete(db.mealEntries)..where((t) => t.id.equals(id))).go();
  }
}

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository(ref.watch(databaseProvider));
});