import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthy_spirit/domain/calculators/food_calculator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/db/app_database.dart';
import '../../data/models/meal_type.dart';
import '../../data/repositories/diary_repository.dart';
import '../diary/diary_providers.dart';

/// Открывает панель: граммы, расчёт КБЖУ, выбор приёма пищи.
/// Если передан [editing], панель меняет граммы существующей записи.
Future<void> showAddProductSheet(
  BuildContext context, {
  required Product product,
  MealType? initialMeal,
  DiaryItem? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AddProductSheet(
      product: product,
      initialMeal: initialMeal,
      editing: editing,
    ),
  );
}

class _AddProductSheet extends ConsumerStatefulWidget {
  final Product product;
  final MealType? initialMeal;
  final DiaryItem? editing;

  const _AddProductSheet({
    required this.product,
    this.initialMeal,
    this.editing,
  });

  @override
  ConsumerState<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<_AddProductSheet> {
  late final TextEditingController _controller;
  late double _grams;
  late MealType _meal;

  @override
  void initState() {
    super.initState();
    _grams = widget.editing?.entry.grams ?? widget.product.portionG;
    _meal = widget.editing?.mealType ??
        widget.initialMeal ??
        _mealByTime(DateTime.now());
    _controller = TextEditingController(text: fmtNum(_grams));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Подсказываем приём пищи по времени суток
  MealType _mealByTime(DateTime t) {
    if (t.hour < 11) return MealType.breakfast;
    if (t.hour < 16) return MealType.lunch;
    if (t.hour < 21) return MealType.dinner;
    return MealType.snack;
  }

  void _setGrams(double v) {
    final value = v.clamp(1, 5000).toDouble();
    setState(() => _grams = value);
    _controller.text = fmtNum(value);
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  Future<void> _submit() async {
    final repo = ref.read(diaryRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (widget.editing != null) {
      await repo.updateGrams(widget.editing!.entry.id, _grams);
    } else {
      await repo.addEntry(
        date: ref.read(selectedDateProvider),
        type: _meal,
        productId: widget.product.id,
        grams: _grams,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('${widget.product.name} добавлен в «${_meal.label}»'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final n = FoodNutrients.forGrams(
      kcalPer100: p.kcal,
      proteinPer100: p.protein,
      fatPer100: p.fat,
      carbsPer100: p.carbs,
      grams: _grams,
    );

    final quick = <double>[50, 100, 150, 200];
    final showPortion = p.portionG != 100 && !quick.contains(p.portionG);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'На 100 г: ${fmtNum(p.kcal)} ккал · Б ${fmtNum(p.protein)} · '
            'Ж ${fmtNum(p.fat)} · У ${fmtNum(p.carbs)}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Ввод граммов
          Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                onTap: () => _setGrams(_grams - 10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    fillColor: AppColors.surfaceLight,
                    suffixText: 'г',
                  ),
                  onChanged: (t) {
                    final v = double.tryParse(t.replaceAll(',', '.'));
                    setState(() => _grams = (v == null || v <= 0) ? 0 : v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              _StepButton(
                icon: Icons.add_rounded,
                onTap: () => _setGrams(_grams <= 0 ? 10 : _grams + 10),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Быстрый выбор граммов
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in quick)
                _QuickChip(
                  label: '${fmtNum(g)} г',
                  selected: _grams == g,
                  onTap: () => _setGrams(g),
                ),
              if (showPortion)
                _QuickChip(
                  label: 'Порция ${fmtNum(p.portionG)} г',
                  selected: _grams == p.portionG,
                  onTap: () => _setGrams(p.portionG),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Расчёт КБЖУ для введённых граммов
          Row(
            children: [
              _NutrientCell('Ккал', n.kcal.round().toString(),
                  AppColors.accentOrange),
              const SizedBox(width: 8),
              _NutrientCell('Б', fmtNum(n.protein), AppColors.protein),
              const SizedBox(width: 8),
              _NutrientCell('Ж', fmtNum(n.fat), AppColors.fat),
              const SizedBox(width: 8),
              _NutrientCell('У', fmtNum(n.carbs), AppColors.carbs),
            ],
          ),

          // Выбор приёма пищи (только при добавлении)
          if (widget.editing == null) ...[
            const SizedBox(height: 20),
            const Text(
              'Приём пищи',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in MealType.values)
                  _QuickChip(
                    label: m.label,
                    selected: _meal == m,
                    onTap: () => setState(() => _meal = m),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _grams > 0 ? _submit : null,
            child: Text(
              widget.editing != null
                  ? 'Сохранить'
                  : 'Добавить в «${_meal.label}»',
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: AppColors.surfaceLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _NutrientCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _NutrientCell(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}