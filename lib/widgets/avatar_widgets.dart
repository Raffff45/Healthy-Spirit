import 'package:material_ui/material_ui.dart';
import '../core/theme/app_colors.dart';
import '../data/models/avatar.dart';

/// Круглая аватарка
class AvatarCircle extends StatelessWidget {
  final String avatarId;
  final double size;

  const AvatarCircle({super.key, required this.avatarId, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final a = avatarById(avatarId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: a.color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: a.color.withValues(alpha: 0.6), width: 2),
      ),
      child: Icon(a.icon, color: a.color, size: size * 0.52),
    );
  }
}

/// Выбор аватарки из готового набора
class AvatarPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const AvatarPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final a in avatarDefs)
          GestureDetector(
            onTap: () => onChanged(a.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected == a.id ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Icon(a.icon, color: a.color, size: 28),
            ),
          ),
      ],
    );
  }
}