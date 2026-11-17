import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthy_spirit/domain/achievements/streak_calculator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/models/achievement.dart';
import '../../data/models/activity_level.dart';
import '../../data/models/gender.dart';
import '../../data/models/goal.dart';
import '../../data/repositories/profile_repository.dart';
import '../../widgets/avatar_widgets.dart';
import '../../widgets/phone_width.dart';
import '../diary/diary_providers.dart';
import '../onboarding/onboarding_provider.dart';
import '../statistics/statistics_screen.dart';
import 'account_card.dart';
import 'edit_profile_screen.dart';

String _daysWord(int n) {
  final m10 = n % 10;
  final m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'день';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'дня';
  return 'дней';
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить все данные?'),
        content: const Text(
          'Профиль, дневник и история веса будут удалены. '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(profileRepositoryProvider).resetAll();
    ref.invalidate(profileProvider);
    ref.invalidate(onboardingProvider);
    if (context.mounted) context.go('/goal');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final streak = ref.watch(streakProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final goal = Goal.values.byName(profile.goal);
    final gender = Gender.values.byName(profile.gender);
    final activity = ActivityLevel.values.byName(profile.activity);
    final diff = (profile.targetWeightKg - profile.weightKg).abs();
    final best = streak?.best ?? 0;
    final isMaintain = goal == Goal.maintain;
    final name = profile.name.trim();

    void openEdit() => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EditProfileScreen(profile: profile),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: SafeArea(
        child: PhoneWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // Шапка: аватарка, имя, цель (нажатие открывает редактирование)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: openEdit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      AvatarCircle(avatarId: profile.avatar, size: 68),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Мой профиль' : name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMaintain
                                  ? 'Цель: ${goal.label}'
                                  : 'Цель: ${goal.label} · до '
                                      '${fmtNum(profile.targetWeightKg)} кг',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (name.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  'Нажми, чтобы добавить имя',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.edit_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Вес
              Row(
                children: [
                  _StatCard('${fmtNum(profile.weightKg)} кг', 'Текущий вес'),
                  const SizedBox(width: 10),
                  _StatCard(
                    isMaintain ? '—' : '${fmtNum(profile.targetWeightKg)} кг',
                    'Целевой вес',
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    isMaintain ? '—' : '${fmtNum(diff)} кг',
                    'До цели',
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Норма
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.accentOrange,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Дневная норма',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${profile.targetKcal} ккал',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Б ${profile.proteinG} г · Ж ${profile.fatG} г · '
                            'У ${profile.carbsG} г',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Переход на статистику
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StatisticsScreen(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.show_chart_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Статистика',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'График веса и калории за неделю',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Достижения
              const _SectionTitle('Достижения'),
              _StreakCard(streak),
              const SizedBox(height: 12),
              for (final def in achievementDefs) ...[
                _AchievementCard(def: def, best: best),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),

              // Параметры
              const _SectionTitle('Параметры'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _InfoRow('Пол', gender.label),
                    _InfoRow('Возраст', '${profile.age} лет'),
                    _InfoRow('Рост', '${profile.heightCm} см'),
                    _InfoRow('Активность', activity.label),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Аккаунт и выход
              const AccountCard(),
              const SizedBox(height: 14),

              ElevatedButton.icon(
                onPressed: openEdit,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Редактировать профиль'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmReset(context, ref),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.accentOrange,
                  side: const BorderSide(color: AppColors.accentOrange),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Сбросить все данные'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final StreakStats? stats;

  const _StreakCard(this.stats);

  @override
  Widget build(BuildContext context) {
    final current = stats?.current ?? 0;
    final best = stats?.best ?? 0;
    final todayClosed = stats?.todayClosed ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.accentOrange,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Серия: $current ${_daysWord(current)} подряд',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Рекорд: $best ${_daysWord(best)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  todayClosed
                      ? 'Сегодняшняя цель закрыта ✓'
                      : 'Чтобы закрыть день, съешь 90–110% нормы калорий',
                  style: TextStyle(
                    fontSize: 12,
                    color: todayClosed
                        ? AppColors.primary
                        : AppColors.textSecondary,
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

class _AchievementCard extends StatelessWidget {
  final AchievementDef def;
  final int best;

  const _AchievementCard({required this.def, required this.best});

  @override
  Widget build(BuildContext context) {
    final unlocked = best >= def.days;
    final progress = (best / def.days).clamp(0.0, 1.0).toDouble();
    final color = unlocked ? def.color : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked ? def.color : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              unlocked ? def.icon : Icons.lock_outline_rounded,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        def.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: unlocked
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (unlocked)
                      Icon(Icons.check_circle_rounded,
                          color: def.color, size: 20),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  def.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      color: def.color,
                      backgroundColor: AppColors.surfaceLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$best из ${def.days} ${_daysWord(def.days)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}