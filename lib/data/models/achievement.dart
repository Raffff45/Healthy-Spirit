import 'package:material_ui/material_ui.dart';

/// Описание достижения: за сколько дней подряд с закрытой дневной целью
class AchievementDef {
  final int days;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const AchievementDef({
    required this.days,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const achievementDefs = <AchievementDef>[
  AchievementDef(
    days: 3,
    title: 'Первые шаги',
    description: 'Закрой дневную цель 3 дня подряд',
    icon: Icons.directions_walk_rounded,
    color: Color(0xFF6CD25C),
  ),
  AchievementDef(
    days: 7,
    title: 'Неделя силы',
    description: 'Закрой дневную цель 7 дней подряд',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFF2A23A),
  ),
  AchievementDef(
    days: 30,
    title: 'Железная воля',
    description: 'Закрой дневную цель 30 дней подряд',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFFACC15),
  ),
];