import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/goal.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/calculators/nutrition_calculator.dart';
import '../diary/diary_providers.dart';
import 'onboarding_provider.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(onboardingProvider);
    final goal = s.goal ?? Goal.maintain;

    final r = NutritionCalculator.calculate(
      gender: s.gender,
      age: s.age,
      heightCm: s.height,
      weightKg: s.weight.toDouble(),
      targetWeightKg: s.targetWeight.toDouble(),
      activity: s.activity,
      goal: goal,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Итоговый расчёт')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 220,
                            height: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: 1,
                                    strokeWidth: 14,
                                    color: AppColors.primary,
                                    backgroundColor: AppColors.surfaceLight,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.local_fire_department_rounded,
                                      color: AppColors.accentOrange,
                                      size: 30,
                                    ),
                                    Text(
                                      '${r.targetKcal}',
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const Text(
                                      'ккал / день',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              _MacroCard('Б', r.protein, AppColors.protein),
                              const SizedBox(width: 12),
                              _MacroCard('Ж', r.fat, AppColors.fat),
                              const SizedBox(width: 12),
                              _MacroCard('У', r.carbs, AppColors.carbs),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _ForecastCard(
                            goal: goal,
                            weeks: r.weeks,
                            targetWeight: s.targetWeight,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(profileRepositoryProvider).saveProfile(
                            name: s.name.trim(),
                            avatar: s.avatar,
                            gender: s.gender,
                            age: s.age,
                            heightCm: s.height,
                            weightKg: s.weight.toDouble(),
                            // При цели «держать вес» целевой вес равен текущему
                            targetWeightKg: goal == Goal.maintain
                                ? s.weight.toDouble()
                                : s.targetWeight.toDouble(),
                            activity: s.activity,
                            goal: goal,
                            result: r,
                          );
                      // Сбрасываем кэш: иначе экраны помнят «профиля нет»
                      ref.invalidate(profileProvider);
                      if (context.mounted) context.go('/home');
                    },
                    child: const Text('Готово'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String letter;
  final int grams;
  final Color color;

  const _MacroCard(this.letter, this.grams, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              letter,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$grams г',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final Goal goal;
  final int? weeks;
  final int targetWeight;

  const _ForecastCard({
    required this.goal,
    required this.weeks,
    required this.targetWeight,
  });

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;

    if (goal == Goal.maintain || weeks == null) {
      title = 'Поддержание веса';
      subtitle = 'Ешьте по норме, и вес останется стабильным';
    } else {
      title = '≈ $weeks нед.';
      subtitle = 'до $targetWeight кг';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.accentOrange,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Прогноз цели',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}