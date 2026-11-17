import 'package:material_ui/material_ui.dart';
import '../core/theme/app_assets.dart';
import '../core/theme/app_colors.dart';

/// Соотношение сторон картинок (941 × 1672).
const double _imageAspect = 941 / 1672;

/// Фон-картинка под содержимым [child].
/// При смене [asset] картинки плавно перетекают друг в друга.
///
/// На узком экране (телефон) картинка заполняет весь экран.
/// На широком (окно на компьютере) она показывается колонкой по центру
/// с мягкими краями — как раз за колонкой приложения.
class AppBackground extends StatelessWidget {
  final String asset;
  final double dim;
  final Widget child;

  const AppBackground({
    super.key,
    required this.asset,
    required this.child,
    this.dim = 0.2,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.background),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: _BackgroundImage(
            key: ValueKey('$asset|$dim'),
            asset: asset,
            dim: dim,
          ),
        ),
        child,
      ],
    );
  }
}

class _BackgroundImage extends StatelessWidget {
  final String asset;
  final double dim;

  const _BackgroundImage({super.key, required this.asset, required this.dim});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final image = Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              // если файла нет — просто тёмный фон, без красных ошибок
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
            ColoredBox(color: Colors.black.withValues(alpha: dim)),
          ],
        );

        final wide = c.maxWidth / c.maxHeight > _imageAspect;
        if (!wide) return image;

        return Center(
          child: SizedBox(
            width: c.maxHeight * _imageAspect,
            height: c.maxHeight,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                colors: [
                  Color(0x00000000),
                  Color(0xFF000000),
                  Color(0xFF000000),
                  Color(0x00000000),
                ],
                stops: [0, 0.15, 0.85, 1],
              ).createShader(rect),
              child: image,
            ),
          ),
        );
      },
    );
  }
}

/// Общий фон всего приложения (травяной). Ставится в MaterialApp.builder.
/// Заодно заранее загружает все картинки, чтобы не было мигания.
class AppBackdrop extends StatefulWidget {
  final Widget child;

  const AppBackdrop({super.key, required this.child});

  @override
  State<AppBackdrop> createState() => _AppBackdropState();
}

class _AppBackdropState extends State<AppBackdrop> {
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final path in AppAssets.all) {
      precacheImage(AssetImage(path), context, onError: (e, s) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(asset: AppAssets.grass1, child: widget.child);
  }
}