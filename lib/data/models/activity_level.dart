enum ActivityLevel {
  sedentary('Сидячий образ жизни', 1.2),
  light('Лёгкая (1–3 тренировки в неделю)', 1.375),
  moderate('Умеренная (3–5 тренировок в неделю)', 1.55),
  high('Высокая (6–7 тренировок в неделю)', 1.725);

  final String label;
  final double factor;
  const ActivityLevel(this.label, this.factor);
}