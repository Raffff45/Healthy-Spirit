import 'dart:math';
import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/phone_width.dart';
import 'games_common.dart';
import 'games_data.dart';

/// Игра «Полезное или вредное»: угадай, к какой группе относится продукт.
/// 3 жизни, ошибка — минус сердечко и подсказка, почему.
class SortGameScreen extends StatefulWidget {
  const SortGameScreen({super.key});

  @override
  State<SortGameScreen> createState() => _SortGameScreenState();
}

class _SortGameScreenState extends State<SortGameScreen> {
  final _rnd = Random();
  late List<Food> _deck;
  int _index = 0;
  int _score = 0;
  int _lives = 3;
  bool? _lastCorrect;
  bool _locked = false;
  bool _over = false;
  bool _record = false;
  int _best = 0;

  Food get _food => _deck[_index];

  @override
  void initState() {
    super.initState();
    _deck = _newDeck();
    GameScores.best(GameId.sort).then((v) {
      if (mounted) setState(() => _best = v);
    });
  }

  List<Food> _newDeck([Food? last]) {
    final d = [...gameFoods]..shuffle(_rnd);
    // чтобы первая карточка новой колоды не повторяла последнюю старой
    if (last != null && d.first == last) {
      final swap = d.removeAt(0);
      d.add(swap);
    }
    return d;
  }

  void _restart() {
    setState(() {
      _deck = _newDeck();
      _index = 0;
      _score = 0;
      _lives = 3;
      _lastCorrect = null;
      _locked = false;
      _over = false;
      _record = false;
    });
  }

  Future<void> _answer(bool saysHealthy) async {
    if (_locked || _over) return;
    final correct = saysHealthy == _food.healthy;
    setState(() {
      _locked = true;
      _lastCorrect = correct;
      if (correct) {
        _score++;
      } else {
        _lives--;
      }
    });

    await Future.delayed(Duration(milliseconds: correct ? 1100 : 2400));
    if (!mounted) return;

    if (_lives <= 0) {
      final record = await GameScores.submit(GameId.sort, _score);
      final best = await GameScores.best(GameId.sort);
      if (!mounted) return;
      setState(() {
        _over = true;
        _record = record;
        _best = best;
      });
      return;
    }

    setState(() {
      final last = _food;
      _index++;
      if (_index >= _deck.length) {
        _deck = _newDeck(last);
        _index = 0;
      }
      _lastCorrect = null;
      _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Полезное или вредное')),
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
    final correct = _lastCorrect;
    final Color border = correct == null
        ? AppColors.surfaceLight
        : (correct ? AppColors.primary : GameColors.bad);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            LivesRow(lives: _lives),
            ScoreChip(score: _score),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Container(
                key: ValueKey('$_index-${_food.name}'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: border, width: 3),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_food.emoji, style: const TextStyle(fontSize: 96)),
                    const SizedBox(height: 12),
                    Text(
                      _food.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 84,
          child: correct == null
              ? const Center(
                  child: Text(
                    'Это полезное или вредное?',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      correct
                          ? 'Верно!'
                          : 'Неверно — это ${_food.healthy ? 'полезное' : 'вредное'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: correct ? AppColors.primary : GameColors.bad,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _food.tip,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _locked ? null : () => _answer(true),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 64),
                ),
                child: const Text('🥗 Полезное'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _locked ? null : () => _answer(false),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 64),
                  backgroundColor: AppColors.accentOrange,
                ),
                child: const Text('🍔 Вредное'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}