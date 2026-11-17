import 'package:material_ui/material_ui.dart';

/// Готовая аватарка: идентификатор хранится в базе и в облаке
class AvatarDef {
  final String id;
  final IconData icon;
  final Color color;

  const AvatarDef(this.id, this.icon, this.color);
}

const avatarDefs = <AvatarDef>[
  AvatarDef('eco', Icons.eco_rounded, Color(0xFF6CD25C)),
  AvatarDef('apple', Icons.apple, Color(0xFFE5534B)),
  AvatarDef('fitness', Icons.fitness_center_rounded, Color(0xFFF2A23A)),
  AvatarDef('run', Icons.directions_run_rounded, Color(0xFF3B82F6)),
  AvatarDef('yoga', Icons.self_improvement_rounded, Color(0xFF9B7BE0)),
  AvatarDef('spa', Icons.spa_rounded, Color(0xFF4FC3B0)),
  AvatarDef('bolt', Icons.bolt_rounded, Color(0xFFFACC15)),
  AvatarDef('heart', Icons.favorite_rounded, Color(0xFFEC6A8E)),
  AvatarDef('rocket', Icons.rocket_launch_rounded, Color(0xFF5B8DEF)),
  AvatarDef('flower', Icons.local_florist_rounded, Color(0xFFE08A5B)),
  AvatarDef('paw', Icons.pets_rounded, Color(0xFFB08968)),
  AvatarDef('trophy', Icons.emoji_events_rounded, Color(0xFFFFC857)),
];

AvatarDef avatarById(String id) {
  return avatarDefs.firstWhere(
    (a) => a.id == id,
    orElse: () => avatarDefs.first,
  );
}