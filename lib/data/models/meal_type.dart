import 'package:material_ui/material_ui.dart';

enum MealType {
  breakfast('Завтрак', Icons.wb_sunny_rounded, 0.25),
  lunch('Обед', Icons.restaurant_rounded, 0.35),
  dinner('Ужин', Icons.nights_stay_rounded, 0.25),
  snack('Перекус', Icons.cookie_rounded, 0.15);

  final String label;
  final IconData icon;

  /// Доля суточной нормы калорий на этот приём пищи
  final double share;

  const MealType(this.label, this.icon, this.share);
}