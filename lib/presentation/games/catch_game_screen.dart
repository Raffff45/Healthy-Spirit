import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/phone_width.dart';
import 'games_common.dart';
import 'games_data.dart';

class _Falling {
  final Food food;
  final double x; // центр по горизонтали, px
  double y; // верх, px
  final double speedMul;

  _Falling(this.food, this.x, this.y, this.speedMul);
}

/// Игра «Поймай полезное»: ловим корзиной полезные продукты,
/// вредные пропускаем. Поймал вредное — минус жизнь.
///
/// Управление: тянуть пальцем / вести мышью, либо стрелки ← → (A / D).
class CatchGameScreen extends StatefulWidget {
  const CatchGameScreen({super.key});

  @override
  State<CatchGameScreen> createState() => _CatchGameScreenState();
}

class _CatchGameScreenState extends State<CatchGameScreen>
    with SingleTickerProviderStateMixin {
  static const double _basketW = 96;
  static const double _basketH = 56;
  static const double _itemSize = 44;

  final _rnd = Random();
  late final Ticker _ticker;
  final FocusNode _focus = FocusNode();
  final List<_Falling> _items = [];

  Duration _last = Duration.zero;
  double _spawnIn = 0.6;
  double _fieldW = 0;
  double _fieldH = 0;
  double _basketX = 0;
  bool _left = false;
  bool _right = false;

  int _score = 0;
  int _lives = 3;
  bool _started = false;
  bool _over = false;
  bool _record = false;
  int _best = 0;

  Color? _flashColor;
  double _flashLeft = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    GameScores.best(GameId.catcher).then((v) {
      if (mounted) setState(() => _best = v);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _items.clear();
      _score = 0;
      _lives = 3;
      _spawnIn = 0.6;
      _basketX = _fieldW / 2;
      _flashColor = null;
      _over = false;
      _record = false;
      _started = true;
    });
    _focus.requestFocus();
  }

  void _moveBasket(double x) {
    if (_fieldW == 0) return;
    _basketX = x.clamp(_basketW / 2, _fieldW - _basketW / 2).toDouble();
  }

  void _spawn() {
    final healthy = _rnd.nextDouble() < 0.65;
    final food = randomFood(_rnd, healthy ? healthyFoods : junkFoods);
    final x = _itemSize / 2 + _rnd.nextDouble() * (_fieldW - _itemSize);
    _items.add(_Falling(food, x, -_itemSize, 0.85 + _rnd.nextDouble() * 0.3));
  }

  void _tick(Duration elapsed) {
    final dt =
        ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = elapsed;
    if (!_started || _over || _fieldW == 0) return;

    // управление с клавиатуры
    final dir = (_right ? 1 : 0) - (_left ? 1 : 0);
    if (dir != 0) _moveBasket(_basketX + dir * 560 * dt);

    // появление новых продуктов
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawn();
      _spawnIn = max(0.4, 1.0 - _score * 0.015) * (0.8 + _rnd.nextDouble() * 0.4);
    }

    // движение и столкновения
    final speed = min(150 + _score * 4.0, 380.0);
    final basketTop = _fieldH - _basketH - 8;
    final remove = <_Falling>[];

    for (final it in _items) {
      it.y += speed * it.speedMul * dt;
      final bottom = it.y + _itemSize;
      final inBasketX = (it.x - _basketX).abs() < (_basketW / 2 + _itemSize / 4);
      if (bottom >= basketTop + 6 && it.y < basketTop + _basketH * 0.6 && inBasketX) {
        remove.add(it);
        if (it.food.healthy) {
          _score++;
          _flashColor = AppColors.primary;
        } else {
          _lives--;
          _flashColor = GameColors.bad;
        }
        _flashLeft = 0.25;
      } else if (it.y > _fieldH) {
        remove.add(it);
      }
    }
    _items.removeWhere(remove.contains);

    if (_flashLeft > 0) {
      _flashLeft -= dt;
      if (_flashLeft <= 0) _flashColor = null;
    }

    if (_lives <= 0) {
      _finish();
      return;
    }
    setState(() {});
  }

  Future<void> _finish() async {
    setState(() {
      _over = true;
      _items.clear();
      _flashColor = null;
    });
    final record = await GameScores.submit(GameId.catcher, _score);
    final best = await GameScores.best(GameId.catcher);
    if (!mounted) return;
    setState(() {
      _record = record;
      _best = best;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final down = event is! KeyUpEvent;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _left = down;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      _right = down;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поймай полезное')),
      body: SafeArea(
        child: PhoneWidth(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox.expand(
              child: Focus(
                focusNode: _focus,
                autofocus: true,
                onKeyEvent: _onKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.surfaceLight),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: LayoutBuilder(builder: _buildField),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, BoxConstraints c) {
    final firstLayout = _fieldW == 0;
    _fieldW = c.maxWidth;
    _fieldH = c.maxHeight;
    if (firstLayout) {
      _basketX = _fieldW / 2;
    } else {
      _moveBasket(_basketX);
    }

    final basketTop = _fieldH - _basketH - 8;

    return MouseRegion(
      onHover: (e) {
        if (_started && !_over) _moveBasket(e.localPosition.dx);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => _moveBasket(_basketX + d.delta.dx),
        onTapDown: (d) {
          if (_started && !_over) _moveBasket(d.localPosition.dx);
        },
        child: Stack(
          children: [
            for (final it in _items)
              Positioned(
                left: it.x - _itemSize / 2,
                top: it.y,
                child: Text(
                  it.food.emoji,
                  style: const TextStyle(fontSize: _itemSize * 0.8),
                ),
              ),
            Positioned(
              left: _basketX - _basketW / 2,
              top: basketTop,
              child: Container(
                width: _basketW,
                height: _basketH,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (_flashColor ?? Colors.transparent)
                      .withValues(alpha: _flashColor == null ? 0 : 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('🧺', style: TextStyle(fontSize: 44)),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    LivesRow(lives: _lives),
                    ScoreChip(score: _score),
                  ],
                ),
              ),
            ),
            if (!_started) Positioned.fill(child: _intro()),
            if (_over)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: GameResultCard(
                      title: 'Игра окончена',
                      score: _score,
                      best: _best,
                      isRecord: _record,
                      onRestart: _start,
                      onExit: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧺', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          const Text(
            'Лови полезное!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ловим 🍎🥦🐟 — получаем очки.\n'
            'Вредное 🍔🍟🍩 ловить нельзя: это минус сердечко.\n\n'
            'Двигай корзину пальцем или мышью,\nлибо стрелками ← →.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _start,
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 52)),
            child: const Text('Начать'),
          ),
        ],
      ),
    );
  }
}