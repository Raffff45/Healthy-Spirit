import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';

enum GameId { sort, catcher, calories }

class GameColors {
  static const bad = Color(0xFFEF5350);
}

/// Хранение лучших результатов в играх.
class GameScores {
  static String _key(GameId id) => 'game_best_${id.name}';

  static Future<int> best(GameId id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_key(id)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Сохраняет результат, если он лучший. Возвращает true, если это рекорд.
  static Future<bool> submit(GameId id, int score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final old = prefs.getInt(_key(id)) ?? 0;
      if (score > old) {
        await prefs.setInt(_key(id), score);
        return true;
      }
    } catch (_) {}
    return false;
  }
}

/// Сердечки — оставшиеся жизни.
class LivesRow extends StatelessWidget {
  final int lives;
  final int max;

  const LivesRow({super.key, required this.lives, this.max = 3});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              i < lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 24,
              color: i < lives ? GameColors.bad : AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

/// Плашка со счётом.
class ScoreChip extends StatelessWidget {
  final int score;

  const ScoreChip({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.accentOrange, size: 20),
          const SizedBox(width: 6),
          Text(
            '$score',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Карточка с итогом игры.
class GameResultCard extends StatelessWidget {
  final String title;
  final int score;
  final int best;
  final bool isRecord;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  const GameResultCard({
    super.key,
    required this.title,
    required this.score,
    required this.best,
    required this.isRecord,
    required this.onRestart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isRecord ? '🏆' : '🎮', style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text(
            isRecord ? 'Новый рекорд!' : title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const Text(
            'очков',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Лучший результат: $best',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onRestart,
            child: const Text('Играть снова'),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onExit, child: const Text('Выйти')),
        ],
      ),
    );
  }
}