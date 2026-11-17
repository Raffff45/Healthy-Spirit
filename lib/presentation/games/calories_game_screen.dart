import 'dart:math';
import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/phone_width.dart';
import 'games_common.dart';
import 'games_data.dart';

/// Игра «Что калорийнее?»: выбери продукт с большей калорийностью на 100 г.
class CaloriesGameScreen extends StatefulWidget {
  const CaloriesGameScreen({super.key});

  @override
  State<CaloriesGameScreen> createState() => _CaloriesGameScreenState();
}

class _CaloriesGameScreenState extends State<CaloriesGameScreen> {
  final _rnd = Random();
  late Food _a;
  late Food _b;
  int _score = 0;
  int _lives = 3;
  int? _picked; // 0 — левый, 1 — правый
  bool _locked = false;
  bool _over = false;
  bool _record = false;
  int _best = 0;

  @override
  void initState() {
    super.initState();
    _newPair();
    GameScores.best(GameId.calories).then((v) {
      if (mounted) setState(() => _best = v);
    });
  }

  void _newPair() {
    Food a;
    Food b;
    do {
      a = gameFoods[_rnd.nextInt(gameFoods.length)];
      b = gameFoods[_rnd.nextInt(gameFoods.length)];
    } while (a == b || (a.kcal - b.kcal).abs() < 40);
    _a = a;
    _b = b;
  }

  void _restart() {
    setState(() {
      _newPair();
      _score = 0;
      _lives = 3;
      _picked = null;
      _locked = false;
      _over = false;
      _record = false;
    });
  }

  Future<void> _pick(int side) async {
    if (_locked || _over) return;
    final pickedFood = side == 0 ? _a : _b;
    final other = side == 0 ? _b : _a;
    final correct = pickedFood.kcal > other.kcal;

    setState(() {
      _locked = true;
      _picked = side;
      if (correct) {
        _score++;
      } else {
        _lives--;
      }
    });

    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;

    if (_lives <= 0) {
      final record = await GameScores.submit(GameId.calories, _score);
      final best = await GameScores.best(GameId.calories);
      if (!mounted) return;
      setState(() {
        _over = true;
        _record = record;
        _best = best;
      });
      return;
    }

    setState(() {
      _newPair();
      _picked = null;
      _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      asset: AppAssets.game,
      dim: 0.35,
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Что калорийнее?')),
      body: SafeArea(
        child: PhoneWidth(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _over
                ? Center(
                    child: GameResultCard(
                      title: 'Игра окончена',
                      score: _score,
                      best: _best,
                      isRecord: _record,
                      onRestart: _restart,
                      onExit: () => Navigator.of(context).pop(),
                    ),
                  )
                : _buildGame(),
          ),
        ),
      ),
    );
  }

  Widget _buildGame() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            LivesRow(lives: _lives),
            ScoreChip(score: _score),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Что калорийнее?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Калории на 100 г продукта (примерно)',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _foodCard(_a, 0)),
              const SizedBox(width: 12),
              Expanded(child: _foodCard(_b, 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _foodCard(Food food, int side) {
    final other = side == 0 ? _b : _a;
    final isMore = food.kcal > other.kcal;
    final revealed = _picked != null;

    Color border = AppColors.surfaceLight;
    if (revealed) {
      if (isMore) {
        border = AppColors.primary;
      } else if (_picked == side) {
        border = GameColors.bad;
      }
    }

    return GestureDetector(
      onTap: _locked ? null : () => _pick(side),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(food.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              food.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: revealed ? 1 : 0,
              child: Text(
                '${food.kcal} ккал',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isMore ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}