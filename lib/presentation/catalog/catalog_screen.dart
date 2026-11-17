import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../data/db/app_database.dart';
import '../../data/db/seed_products.dart';
import '../../data/models/meal_type.dart';
import '../../data/repositories/product_repository.dart';
import '../../widgets/phone_width.dart';
import 'add_product_sheet.dart';

IconData categoryIcon(String category) {
  switch (category) {
    case 'Мясо и птица':
      return Icons.kebab_dining_rounded;
    case 'Рыба и морепродукты':
      return Icons.set_meal_rounded;
    case 'Молочные и яйца':
      return Icons.egg_alt_rounded;
    case 'Крупы и гарниры':
      return Icons.rice_bowl_rounded;
    case 'Овощи':
      return Icons.eco_rounded;
    case 'Фрукты и ягоды':
      return Icons.apple;
    case 'Бобовые':
      return Icons.grass_rounded;
    case 'Хлеб':
      return Icons.bakery_dining_rounded;
    case 'Орехи и семена':
      return Icons.grain_rounded;
    case 'Масла и добавки':
      return Icons.water_drop_rounded;
    case 'Сладкое':
      return Icons.cake_rounded;
    case 'Напитки':
      return Icons.local_cafe_rounded;
    default:
      return Icons.restaurant_rounded;
  }
}

/// Каталог продуктов. Если задан [pickFor], экран открыт из дневника
/// для добавления в конкретный приём пищи.
class CatalogScreen extends ConsumerStatefulWidget {
  final MealType? pickFor;

  const CatalogScreen({super.key, this.pickFor});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pickFor == null
              ? 'Каталог продуктов'
              : 'Добавить в «${widget.pickFor!.label}»',
        ),
      ),
      body: SafeArea(
        child: PhoneWidth(
          child: products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка: $e')),
            data: (all) {
              final categories = productCategories
                  .where((c) => all.any((p) => p.category == c))
                  .toList();

              final filtered = all.where((p) {
                if (_category != null && p.category != _category) return false;
                if (_query.isNotEmpty &&
                    !p.name.toLowerCase().contains(_query)) {
                  return false;
                }
                return true;
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Поиск продукта...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase()),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _CategoryChip(
                          label: 'Все',
                          selected: _category == null,
                          onTap: () => setState(() => _category = null),
                        ),
                        for (final c in categories)
                          _CategoryChip(
                            label: c,
                            selected: _category == c,
                            onTap: () => setState(() => _category = c),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Ничего не найдено',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) => _ProductTile(
                              product: filtered[i],
                              onTap: () => showAddProductSheet(
                                context,
                                product: filtered[i],
                                initialMeal: widget.pickFor,
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    categoryIcon(p.category),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${fmtNum(p.kcal)} ккал · Б ${fmtNum(p.protein)} · '
                        'Ж ${fmtNum(p.fat)} · У ${fmtNum(p.carbs)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Text(
                        'на 100 г',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}