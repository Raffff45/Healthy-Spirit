import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/models/meal_type.dart';
import '../../data/repositories/diary_repository.dart';
import '../../domain/calculators/food_calculator.dart';
import '../../widgets/phone_width.dart';
import '../catalog/add_product_sheet.dart';
import '../catalog/catalog_screen.dart';
import 'diary_providers.dart';

const _months = [
  'янв.', 'февр.', 'марта', 'апр.', 'мая', 'июня',
  'июля', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.',
];

String _dateTitle(DateTime d) {
  final now = DateTime.now();
  final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
  final base = '${d.day} ${_months[d.month - 1]}';
  return isToday ? 'Сегодня, $base' : '$base ${d.year}';
}

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final profile = ref.watch(profileProvider).value;
    final items = ref.watch(dayEntriesProvider).value ?? const <DiaryItem>[];

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final total = items.fold<FoodNutrients>(
      FoodNutrients.zero,
      (sum, i) => sum + i.nutrients,
    );

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        ref.read(selectedDateProvider.notifier).setDate(picked);
      }
    }

    return Scaffold(
      body: SafeArea(
        child: PhoneWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _DateHeader(
                title: _dateTitle(date),
                onPrev: () =>
                    ref.read(selectedDateProvider.notifier).shift(-1),
                onNext: () => ref.read(selectedDateProvider.notifier).shift(1),
                onPick: pickDate,
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                total: total,
                targetKcal: profile.targetKcal,
                targetProtein: profile.proteinG,
                targetFat: profile.fatG,
                targetCarbs: profile.carbsG,
              ),
              const SizedBox(height: 16),
              for (final type in MealType.values) ...[
                _MealCard(
                  type: type,
                  items: items.where((i) => i.mealType == type).toList(),
                  recommended: (profile.targetKcal * type.share).round(),
                  onAdd: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CatalogScreen(pickFor: type),
                    ),
                  ),
                  onEdit: (item) => showAddProductSheet(
                    context,
                    product: item.product,
                    editing: item,
                  ),
                  onDelete: (item) => ref
                      .read(diaryRepositoryProvider)
                      .deleteEntry(item.entry.id),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String title;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const _DateHeader({
    required this.title,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        IconButton(
          onPressed: onPick,
          icon: const Icon(Icons.calendar_month_rounded),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final FoodNutrients total;
  final int targetKcal;
  final int targetProtein;
  final int targetFat;
  final int targetCarbs;

  const _SummaryCard({
    required this.total,
    required this.targetKcal,
    required this.targetProtein,
    required this.targetFat,
    required this.targetCarbs,
  });

  @override
  Widget build(BuildContext context) {
    final consumed = total.kcal;
    final over = consumed > targetKcal;
    final progress = targetKcal <= 0
        ? 0.0
        : (consumed / targetKcal).clamp(0.0, 1.0).toDouble();
    final left = (targetKcal - consumed).round();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        color:
                            over ? AppColors.accentOrange : AppColors.primary,
                        backgroundColor: AppColors.surfaceLight,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${consumed.round()}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'из $targetKcal ккал',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _MacroBar('Б', total.protein, targetProtein,
                        AppColors.protein),
                    _MacroBar('Ж', total.fat, targetFat, AppColors.fat),
                    _MacroBar('У', total.carbs, targetCarbs, AppColors.carbs),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            over ? 'Превышение на ${-left} ккал' : 'Осталось $left ккал',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: over ? AppColors.accentOrange : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String letter;
  final double value;
  final int target;
  final Color color;

  const _MacroBar(this.letter, this.value, this.target, this.color);

  @override
  Widget build(BuildContext context) {
    final progress =
        target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                letter,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '${value.round()} / $target г',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: color,
              backgroundColor: AppColors.surfaceLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealType type;
  final List<DiaryItem> items;
  final int recommended;
  final VoidCallback onAdd;
  final void Function(DiaryItem) onEdit;
  final void Function(DiaryItem) onDelete;

  const _MealCard({
    required this.type,
    required this.items,
    required this.recommended,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sum = items.fold<FoodNutrients>(
      FoodNutrients.zero,
      (s, i) => s + i.nutrients,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(type.icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${sum.kcal.round()} из $recommended ккал',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onAdd,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                ),
                icon: const Icon(Icons.add_rounded, color: AppColors.primary),
              ),
            ],
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10, left: 4),
              child: Text(
                'Пока ничего не добавлено',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            for (final item in items)
              InkWell(
                onTap: () => onEdit(item),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${fmtNum(item.entry.grams)} г · '
                              '${item.nutrients.kcal.round()} ккал · '
                              'Б ${fmtNum(item.nutrients.protein)} · '
                              'Ж ${fmtNum(item.nutrients.fat)} · '
                              'У ${fmtNum(item.nutrients.carbs)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => onDelete(item),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}