import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthy_spirit/domain/calculators/nutrition_calculator.dart';
import '../../core/utils/avatar_photo_store.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../models/activity_level.dart';
import '../models/gender.dart';
import '../models/goal.dart';

class ProfileRepository {
  final AppDatabase db;
  ProfileRepository(this.db);

  /// Текущий профиль или null, если онбординг ещё не пройден
  Future<UserProfile?> getProfile() {
    return (db.select(db.userProfiles)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Сохраняет профиль (при онбординге и при редактировании)
  Future<void> saveProfile({
    required String name,
    required String avatar,
    required Gender gender,
    required int age,
    required int heightCm,
    required double weightKg,
    required double targetWeightKg,
    required ActivityLevel activity,
    required Goal goal,
    required NutritionResult result,
  }) async {
    await db.transaction(() async {
      // Профиль один, поэтому старый заменяем новым
      await db.delete(db.userProfiles).go();
      await db.into(db.userProfiles).insert(
            UserProfilesCompanion.insert(
              gender: gender.name,
              age: age,
              heightCm: heightCm,
              weightKg: weightKg,
              targetWeightKg: targetWeightKg,
              activity: activity.name,
              goal: goal.name,
              targetKcal: result.targetKcal,
              proteinG: result.protein,
              fatG: result.fat,
              carbsG: result.carbs,
              name: Value(name),
              avatar: Value(avatar),
            ),
          );

      // Точка для графика веса: только если вес изменился
      final last = await (db.select(db.weightEntries)
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();
      if (last == null || (last.weightKg - weightKg).abs() > 0.01) {
        await db.into(db.weightEntries).insert(
              WeightEntriesCompanion.insert(
                date: DateTime.now(),
                weightKg: weightKg,
              ),
            );
      }
    });

    // удаляем файлы фото, которые больше не используются
    await AvatarPhotoStore.cleanupExcept(avatar);
  }

  /// Записать новый вес: обновляет профиль, пересчитывает норму
  /// и добавляет точку на график
  Future<void> updateWeight(double weightKg) async {
    final p = await getProfile();
    if (p == null) return;

    final goal = Goal.values.byName(p.goal);
    final result = NutritionCalculator.calculate(
      gender: Gender.values.byName(p.gender),
      age: p.age,
      heightCm: p.heightCm,
      weightKg: weightKg,
      targetWeightKg: p.targetWeightKg,
      activity: ActivityLevel.values.byName(p.activity),
      goal: goal,
    );

    await saveProfile(
      name: p.name,
      avatar: p.avatar,
      gender: Gender.values.byName(p.gender),
      age: p.age,
      heightCm: p.heightCm,
      weightKg: weightKg,
      targetWeightKg: p.targetWeightKg,
      activity: ActivityLevel.values.byName(p.activity),
      goal: goal,
      result: result,
    );
  }

  /// История веса по возрастанию даты (для графика)
  Stream<List<WeightEntry>> watchWeights() {
    return (db.select(db.weightEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .watch();
  }

  /// Полная очистка данных (кнопка «Сбросить данные» в профиле)
  Future<void> resetAll() async {
    await db.transaction(() async {
      // Сначала записи дневника, потому что они ссылаются на продукты
      await db.delete(db.mealEntries).go();
      await db.delete(db.weightEntries).go();
      await db.delete(db.userProfiles).go();
    });
    await AvatarPhotoStore.cleanupExcept('');
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(databaseProvider));
});