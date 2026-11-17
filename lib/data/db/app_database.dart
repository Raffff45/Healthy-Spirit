import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'seed_products.dart';

part 'app_database.g.dart';

/// Профиль пользователя (одна строка)
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get gender => text()();
  IntColumn get age => integer()();
  IntColumn get heightCm => integer()();
  RealColumn get weightKg => real()();
  RealColumn get targetWeightKg => real()();
  TextColumn get activity => text()();
  TextColumn get goal => text()();
  IntColumn get targetKcal => integer()();
  IntColumn get proteinG => integer()();
  IntColumn get fatG => integer()();
  IntColumn get carbsG => integer()();
  // Добавлено в версии 2
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get avatar => text().withDefault(const Constant('eco'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Продукты: КБЖУ на 100 г
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  RealColumn get kcal => real()();
  RealColumn get protein => real()();
  RealColumn get fat => real()();
  RealColumn get carbs => real()();
  RealColumn get portionG => real().withDefault(const Constant(100))();
  // Для генератора: на какие приёмы пищи подходит продукт
  TextColumn get mealTypes => text()
      .withDefault(const Constant('breakfast,lunch,dinner,snack'))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}

/// Съеденное: что, когда, сколько граммов
class MealEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get mealType => text()();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get grams => real()();
}

/// История веса для графика
class WeightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weightKg => real()();
}

@DriftDatabase(
  tables: [UserProfiles, Products, MealEntries, WeightEntries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'healthy_spirit'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Обновление со старой версии: данные пользователя сохраняются
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(userProfiles, userProfiles.name);
            await m.addColumn(userProfiles, userProfiles.avatar);
          }
        },
        // При открытии базы: если продуктов нет, загружаем стартовый набор
        beforeOpen: (details) async {
          final existing = await (select(products)..limit(1)).get();
          if (existing.isEmpty) {
            await batch((b) => b.insertAll(products, seedProducts()));
          }
        },
      );
}