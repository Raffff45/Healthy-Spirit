import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/phone_width.dart';
import 'calories_game_screen.dart';
import 'catch_game_screen.dart';
import 'games_common.dart';
import 'sort_game_screen.dart';

/// Вкладка «Игры» — список мини-игр про питание.
class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final Map<GameId, int> _best = {};

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    for (final id in GameId.values) {
      final v = await GameScores.best(id);
      if (!mounted) return;
      setState(() => _best[id] = v);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    _loadScores();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Игры')),
      body: SafeArea(
        child: PhoneWidth(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Проверь, что ты знаешь о питании',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _GameCard(
                emoji: '🥗',
                title: 'Полезное или вредное',
                description: 'Определи, к какой группе относится продукт. '
                    'Три ошибки — и игра окончена.',
                best: _best[GameId.sort],
                onTap: () => _open(const SortGameScreen()),
              ),
              const SizedBox(height: 12),
              _GameCard(
                emoji: '🧺',
                title: 'Поймай полезное',
                description: 'Лови корзиной полезные продукты и уворачивайся '
                    'от фастфуда.',
                best: _best[GameId.catcher],
                onTap: () => _open(const CatchGameScreen()),
              ),
              const SizedBox(height: 12),
              _GameCard(
                emoji: '🔥',
                title: 'Что калорийнее?',
                description: 'Выбери из двух продуктов тот, в котором больше '
                    'калорий.',
                best: _best[GameId.calories],
                onTap: () => _open(const CaloriesGameScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final int? best;
  final VoidCallback onTap;

  const _GameCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.best,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 16,
                          color: AppColors.accentOrange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Рекорд: ${best ?? 0}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.accentOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ],
          ),
        ),
      ),
    );
  }
}