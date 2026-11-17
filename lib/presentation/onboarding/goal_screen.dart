import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/goal.dart';
import 'onboarding_provider.dart';

class _GoalOption {
  final Goal goal;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _GoalOption(this.goal, this.title, this.subtitle, this.icon, this.color);
}

const _options = [
  _GoalOption(
    Goal.lose,
    'Похудеть',
    'Сбросить вес и стать легче',
    Icons.local_fire_department_rounded,
    AppColors.accentOrange,
  ),
  _GoalOption(
    Goal.maintain,
    'Держать вес',
    'Сохранять текущий вес',
    Icons.balance_rounded,
    AppColors.primary,
  ),
  _GoalOption(
    Goal.gain,
    'Набрать массу',
    'Увеличить мышечную массу',
    Icons.fitness_center_rounded,
    Color(0xFFE08A5B),
  ),
];

class GoalScreen extends ConsumerWidget {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).goal;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'Твоя цель?',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Выбери, что тебе нужно',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  for (final option in _options) ...[
                    _GoalCard(
                      option: option,
                      isSelected: selected == option.goal,
                      onTap: () => ref
                          .read(onboardingProvider.notifier)
                          .setGoal(option.goal),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const Spacer(),
                  ElevatedButton(
                    onPressed:
                        selected == null ? null : () => context.push('/survey'),
                    child: const Text('Далее'),
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

class _GoalCard extends StatelessWidget {
  final _GoalOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(option.icon, color: option.color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}