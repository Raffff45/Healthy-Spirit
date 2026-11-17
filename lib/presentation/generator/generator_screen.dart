import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthy_spirit/domain/generator/menu_generator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/diary_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../widgets/phone_width.dart';
import '../diary/diary_providers.dart';

/// Цели по калориям и БЖУ, под которые генерируется меню
class _Targets {
  final int kcal;
  final int protein;
  final int fat;
  final int carbs;

  const _Targets(this.kcal, this.protein, this.fat, this.carbs);

  /// Если калорийность изменена ползунком, БЖУ масштабируется пропорционально
  factory _Targets.scaled(UserProfile p, int kcal) {
    final r = kcal / p.targetKcal;
    return _Targets(
      kcal,
      (p.proteinG * r).round(),
      (p.fatG * r).round(),
      (p.carbsG * r).round(),
    );
  }
}

class GeneratorScreen extends ConsumerStatefulWidget {
  const GeneratorScreen({super.key});

  @override
  ConsumerState<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends ConsumerState<GeneratorScreen> {
  final _generator = MenuGenerator();
  int? _kcal;
  int _mealsCount = 4;
  final Set<int> _excluded = {};
  GeneratedMenu? _menu;
  _Targets? _menuTargets;

  int _initialKcal(int target) =>
      ((target / 50).round() * 50).clamp(1200, 4000).toInt();

  void _generate(UserProfile profile, List<Product> products, int kcal) {
    final t = _Targets.scaled(profile, kcal);
    setState(() {
      _menuTargets = t;
      _menu = _generator.generateDay(
        products: products,
        dayKcal: t.kcal,
        dayProtein: t.protein,
        dayFat: t.fat,
        dayCarbs: t.carbs,
        mealsCount: _mealsCount,
        excludedIds: _excluded,
      );
    });
  }

  void _regenerateMeal(int index, List<Product> products) {
    final menu = _menu;
    final t = _menuTargets;
    if (menu == null || t == null) return;

    final old = menu.meals[index];
    // Все уже использованные продукты, чтобы блюдо получилось другим
    final used = <int>{
      for (final m in menu.meals)
        for (final i in m.items) i.product.id,
    };

    final meal = _generator.generateMeal(
      products: products,
      type: old.type,
      share: old.share,
      dayKcal: t.kcal,
      dayProtein: t.protein,
      dayFat: t.fat,
      dayCarbs: t.carbs,
      excludedIds: _excluded,
      usedIds: used,
    );

    final meals = [...menu.meals];
    meals[index] = meal;
    setState(() => _menu = GeneratedMenu(meals));
  }

  Future<void> _pickExcluded(List<Product> products) async {
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: 520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExcludePicker(
        products: products.where((p) => !_excluded.contains(p.id)).toList(),
      ),
    );
    if (picked != null) {
      setState(() => _excluded.add(picked.id));
    }
  }

  Future<void> _saveToDiary() async {
    final menu = _menu;
    if (menu == null) return;

    final date = ref.read(selectedDateProvider);
    final messenger = ScaffoldMessenger.of(context);

    await ref.read(diaryRepositoryProvider).addEntries(date, [
      for (final meal in menu.meals)
        for (final item in meal.items)
          NewDiaryEntry(meal.type, item.product.id, item.grams),
    ]);

    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    messenger.showSnackBar(
      SnackBar(content: Text('Меню добавлено в дневник за $d.$m')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final products = ref.watch(productsProvider).value;

    if (profile == null || products == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final kcal = _kcal ?? _initialKcal(profile.targetKcal);
    final excludedProducts =
        products.where((p) => _excluded.contains(p.id)).toList();
    final menu = _menu;
    final targets = _menuTargets;

    return Scaffold(
      appBar: AppBar(title: const Text('Генератор меню')),
      body: SafeArea(
        child: PhoneWidth(  
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              // Калорийность
              const _SectionLabel('Калорийность'),
              Text(
                '$kcal ккал',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Slider(
                value: kcal.toDouble(),
                min: 1200,
                max: 4000,
                divisions: 56,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _kcal = v.round()),
              ),
              const SizedBox(height: 8),

              // Число приёмов пищи
              const _SectionLabel('Приёмов пищи'),
              Row(
                children: [
                  for (final n in const [3, 4, 5]) ...[
                    Expanded(
                      child: _CountChip(
                        label: '$n',
                        selected: _mealsCount == n,
                        onTap: () => setState(() => _mealsCount = n),
                      ),
                    ),
                    if (n != 5) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // Исключения
              const _SectionLabel('Исключить продукты'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in excludedProducts)
                    InputChip(
                      label: Text(p.name),
                      onDeleted: () => setState(() => _excluded.remove(p.id)),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Добавить'),
                    onPressed: () => _pickExcluded(products),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () => _generate(profile, products, kcal),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(menu == null ? 'Составить меню' : 'Составить заново'),
              ),

              if (menu != null && targets != null) ...[
                const SizedBox(height: 28),
                const Text(
                  'Ваше меню на день',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _SummaryCard(menu: menu, targets: targets),
                const SizedBox(height: 12),
                for (var i = 0; i < menu.meals.length; i++) ...[
                  _MealResultCard(
                    meal: menu.meals[i],
                    onRegenerate: () => _regenerateMeal(i, products),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: _saveToDiary,
                  child: const Text('Добавить в дневник'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CountChip({
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Итог по меню: сумма и отклонение от цели
class _SummaryCard extends StatelessWidget {
  final GeneratedMenu menu;
  final _Targets targets;

  const _SummaryCard({required this.menu, required this.targets});

  @override
  Widget build(BuildContext context) {
    final total = menu.total;
    final dev = targets.kcal <= 0
        ? 0.0
        : (total.kcal - targets.kcal) / targets.kcal * 100;
    final devText = '${dev >= 0 ? '+' : ''}${dev.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SumCell('Ккал', '${total.kcal.round()}', '${targets.kcal}',
                  AppColors.accentOrange),
              _SumCell('Б', fmtNum(total.protein), '${targets.protein}',
                  AppColors.protein),
              _SumCell('Ж', fmtNum(total.fat), '${targets.fat}',
                  AppColors.fat),
              _SumCell('У', fmtNum(total.carbs), '${targets.carbs}',
                  AppColors.carbs),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Отклонение по калориям: $devText',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SumCell extends StatelessWidget {
  final String label;
  final String value;
  final String target;
  final Color color;

  const _SumCell(this.label, this.value, this.target, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'цель $target',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealResultCard extends StatelessWidget {
  final GeneratedMeal meal;
  final VoidCallback onRegenerate;

  const _MealResultCard({required this.meal, required this.onRegenerate});

  @override
  Widget build(BuildContext context) {
    final total = meal.total;

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
                child: Icon(meal.type.icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.type.label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${total.kcal.round()} ккал · цель ${meal.targetKcal}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Заменить блюдо',
                onPressed: onRegenerate,
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (meal.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                'Не удалось подобрать продукты. Проверь список исключений.',
                style: TextStyle(fontSize: 13, color: AppColors.accentOrange),
              ),
            )
          else
            for (final item in meal.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.product.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${fmtNum(item.grams)} г · '
                      '${item.nutrients.kcal.round()} ккал',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          if (meal.items.isNotEmpty) ...[
            const Divider(height: 18),
            Text(
              'Б ${fmtNum(total.protein)} · Ж ${fmtNum(total.fat)} · '
              'У ${fmtNum(total.carbs)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Панель выбора продукта для исключения
class _ExcludePicker extends StatefulWidget {
  final List<Product> products;

  const _ExcludePicker({required this.products});

  @override
  State<_ExcludePicker> createState() => _ExcludePickerState();
}

class _ExcludePickerState extends State<_ExcludePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.products
        .where((p) => p.name.toLowerCase().contains(_query))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Найти продукт для исключения...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(list[i].name),
                  subtitle: Text(list[i].category),
                  onTap: () => Navigator.of(context).pop(list[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}