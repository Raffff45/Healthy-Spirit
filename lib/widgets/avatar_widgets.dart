import 'dart:io';

import 'package:material_ui/material_ui.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/avatar_photo_store.dart';
import '../data/models/avatar.dart';

/// Круглая аватарка: готовая иконка или собственное фото
class AvatarCircle extends StatefulWidget {
  final String avatarId;
  final double size;
  final bool bordered;

  const AvatarCircle({
    super.key,
    required this.avatarId,
    this.size = 64,
    this.bordered = true,
  });

  @override
  State<AvatarCircle> createState() => _AvatarCircleState();
}

class _AvatarCircleState extends State<AvatarCircle> {
  Future<File?>? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AvatarCircle old) {
    super.didUpdateWidget(old);
    if (old.avatarId != widget.avatarId) _load();
  }

  void _load() {
    _file = AvatarPhotoStore.isPhoto(widget.avatarId)
        ? AvatarPhotoStore.fileFor(widget.avatarId)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final future = _file;
    if (future == null) return _iconCircle();

    return FutureBuilder<File?>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _frame(child: const SizedBox.shrink());
        }
        final file = snap.data;
        // файла нет (другое устройство): иконка по умолчанию
        if (file == null) return _iconCircle();
        return _frame(
          child: SizedBox.expand(
            child: Image.file(
              file,
              key: ValueKey(file.path),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              cacheWidth: (widget.size * 3).round(),
              errorBuilder: (context, error, stack) =>
                  const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  Widget _frame({required Widget child}) {
    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      foregroundDecoration: widget.bordered
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            )
          : null,
      child: child,
    );
  }

  Widget _iconCircle() {
    final a = avatarById(widget.avatarId);
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: a.color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: a.color.withValues(alpha: 0.6), width: 2),
      ),
      child: Icon(a.icon, color: a.color, size: widget.size * 0.52),
    );
  }
}

/// Выбор аватарки: своё фото или готовая иконка из набора
class AvatarPicker extends StatefulWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const AvatarPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  /// Последнее выбранное фото: чтобы можно было вернуться к нему
  String? _photoId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (AvatarPhotoStore.isPhoto(widget.selected)) _photoId = widget.selected;
  }

  Future<void> _onPhotoTap() async {
    final photo = _photoId;
    // Фото есть, но выбрана иконка: возвращаемся к фото.
    // Нажатие на уже выбранное фото открывает выбор нового.
    if (photo != null && widget.selected != photo) {
      widget.onChanged(photo);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = await AvatarPhotoStore.pickAndSave();
      if (id != null && mounted) {
        setState(() => _photoId = id);
        widget.onChanged(id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить фото')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photoId;
    final photoSelected = photo != null && widget.selected == photo;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        Tooltip(
          message: photoSelected ? 'Выбрать другое фото' : 'Своё фото',
          child: GestureDetector(
            onTap: _onPhotoTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      photoSelected ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
              child: _busy
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : photo == null
                      ? const Icon(
                          Icons.add_a_photo_rounded,
                          color: AppColors.textSecondary,
                          size: 26,
                        )
                      : AvatarCircle(
                          avatarId: photo,
                          size: 56,
                          bordered: false,
                        ),
            ),
          ),
        ),
        for (final a in avatarDefs)
          GestureDetector(
            onTap: () => widget.onChanged(a.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: a.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.selected == a.id
                      ? AppColors.primary
                      : Colors.transparent,
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