import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthy_spirit/domain/achievements/streak_calculator.dart';
import 'package:healthy_spirit/domain/calculators/food_calculator.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/diary_repository.dart';
import '../../data/repositories/profile_repository.dart';

/// Выбранный в дневнике день
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void shift(int days) {
    state = DateTime(state.year, state.month, state.day + days);
  }

  void setDate(DateTime d) {
    state = DateTime(d.year, d.month, d.day);
  }
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

/// Записи дневника за выбранный день
final dayEntriesProvider = StreamProvider<List<DiaryItem>>((ref) {
  final date = ref.watch(selectedDateProvider);
  return ref.watch(diaryRepositoryProvider).watchDay(date);
});

/// Профиль пользователя (норма калорий и БЖУ)
final profileProvider = FutureProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});

/// Итоги по всем дням
final dailyTotalsProvider = StreamProvider<Map<DateTime, FoodNutrients>>((ref) {
  return ref.watch(diaryRepositoryProvider).watchDailyTotals();
});

/// Серии закрытых дней (для достижений)
final streakProvider = Provider<StreakStats?>((ref) {
  final profile = ref.watch(profileProvider).value;
  final totals = ref.watch(dailyTotalsProvider).value;
  if (profile == null || totals == null) return null;

  return StreakCalculator.calculate(
    dailyKcal: {for (final e in totals.entries) e.key: e.value.kcal},
    targetKcal: profile.targetKcal,
    today: DateTime.now(),
  );
});