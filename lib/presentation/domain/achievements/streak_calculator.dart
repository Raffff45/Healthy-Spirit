/// Статистика серий закрытых дней
class StreakStats {
  final int current; // текущая серия
  final int best; // лучшая серия за всё время
  final bool todayClosed; // закрыта ли сегодняшняя цель

  const StreakStats({
    required this.current,
    required this.best,
    required this.todayClosed,
  });
}

class StreakCalculator {
  /// День закрыт, если съедено от 90% до 110% дневной нормы
  static const double lowerRatio = 0.9;
  static const double upperRatio = 1.1;

  static bool isDayClosed(double kcal, int targetKcal) {
    if (targetKcal <= 0) return false;
    final ratio = kcal / targetKcal;
    return ratio >= lowerRatio && ratio <= upperRatio;
  }

  static DateTime _next(DateTime d) => DateTime(d.year, d.month, d.day + 1);
  static DateTime _prev(DateTime d) => DateTime(d.year, d.month, d.day - 1);

  /// [dailyKcal]: калории по дням (ключ это дата без времени)
  static StreakStats calculate({
    required Map<DateTime, double> dailyKcal,
    required int targetKcal,
    required DateTime today,
  }) {
    final day = DateTime(today.year, today.month, today.day);

    // Будущие дни не считаются: заранее «закрыть» цель нельзя
    final closed = <DateTime>{
      for (final e in dailyKcal.entries)
        if (!e.key.isAfter(day) && isDayClosed(e.value, targetKcal)) e.key,
    };

    final todayClosed = closed.contains(day);

    // Лучшая серия: самая длинная цепочка подряд идущих закрытых дней
    final sorted = closed.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in sorted) {
      if (prev != null && _next(prev) == d) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      prev = d;
    }

    // Текущая серия: идём назад от сегодня (или от вчера, если сегодня
    // ещё не закрыт, чтобы незаконченный день не обрывал серию)
    var cursor = todayClosed ? day : _prev(day);
    var current = 0;
    while (closed.contains(cursor)) {
      current++;
      cursor = _prev(cursor);
    }

    return StreakStats(current: current, best: best, todayClosed: todayClosed);
  }
}