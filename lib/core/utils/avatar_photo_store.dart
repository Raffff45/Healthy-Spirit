import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, FileOptions, StorageException;

/// Собственная фотография-аватарка.
///
/// В поле `avatar` профиля лежит строка `photo:<имя файла>`.
/// Файл хранится на устройстве (кэш) и в Supabase Storage
/// (бакет `avatars`, путь `<user_id>/<имя файла>`).
/// Если на устройстве файла нет, он скачивается из облака.
class AvatarPhotoStore {
  static const prefix = 'photo:';
  static const _bucket = 'avatars';
  static Directory? _dir;
  static final Map<String, Future<File?>> _downloads = {};

  static bool isPhoto(String id) => id.startsWith(prefix);

  static String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  /// Имя файла из идентификатора (с защитой от выхода из папки)
  static String? _safeName(String id) {
    if (!isPhoto(id)) return null;
    final name = id.substring(prefix.length);
    if (name.isEmpty ||
        name.contains('/') ||
        name.contains(r'\') ||
        name.contains('..')) {
      return null;
    }
    return name;
  }

  static Future<Directory> _photosDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}avatars');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  static Future<File> _localPath(String name) async {
    final dir = await _photosDir();
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  static String _uploadedKey(String uid, String name) =>
      'avatar_uploaded_${uid}_$name';

  /// Файл фото: сначала на устройстве, иначе скачиваем из облака.
  /// null, если фото нигде не нашлось.
  static Future<File?> fileFor(String id) async {
    final name = _safeName(id);
    if (name == null) return null;

    final local = await _localPath(name);
    if (await local.exists()) return local;

    return _download(name);
  }

  static Future<File?> _download(String name) {
    final uid = _uid;
    if (uid == null) return Future.value(null);
    // одно скачивание на файл, даже если аватарка показана в нескольких местах
    return _downloads[name] ??=
        _doDownload(uid, name).whenComplete(() => _downloads.remove(name));
  }

  static Future<File?> _doDownload(String uid, String name) async {
    try {
      final bytes = await Supabase.instance.client.storage
          .from(_bucket)
          .download('$uid/$name');
      final file = await _localPath(name);
      await file.writeAsBytes(bytes);
      // файл уже есть в облаке, загружать его повторно не нужно
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_uploadedKey(uid, name), true);
      return file;
    } catch (e) {
      // ignore: avoid_print
      print('AVATAR DOWNLOAD ERROR: $e');
      return null;
    }
  }

  /// Выбор фото из галереи, копия в папку приложения.
  /// Возвращает новый id аватарки, null если выбор отменён.
  /// В облако фото уходит позже, при синхронизации (см. [syncRemote]).
  static Future<String?> pickAndSave() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;

    // уникальное имя, чтобы Flutter не показывал старую картинку из кэша
    final name = 'avatar_${DateTime.now().millisecondsSinceEpoch}';
    final file = await _localPath(name);
    await file.writeAsBytes(await picked.readAsBytes());
    return '$prefix$name';
  }

  /// Синхронизация облака с выбранной аватаркой: загружает новое фото
  /// и удаляет из облака старые. Для обычной иконки ('' тоже подходит)
  /// удаляет все фото пользователя. Вызывается из SyncService.
  /// Бросает исключение при ошибке сети: тогда попробуем при следующей отправке.
  static Future<void> syncRemote(String avatarId) async {
    final uid = _uid;
    if (uid == null) return;
    final storage = Supabase.instance.client.storage.from(_bucket);

    final name = _safeName(avatarId);
    if (name == null) {
      await _removeAllExcept(uid, null);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _uploadedKey(uid, name);

    if (!(prefs.getBool(key) ?? false)) {
      final local = await _localPath(name);
      // файла нет на устройстве: загружать нечего
      if (!await local.exists()) return;

      try {
        await storage.uploadBinary(
          '$uid/$name',
          await local.readAsBytes(),
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      } on StorageException catch (e) {
        // такой файл уже есть в облаке: считаем загруженным
        final duplicate =
            e.statusCode == '409' || e.message.contains('already exists');
        if (!duplicate) rethrow;
      }
      await prefs.setBool(key, true);
    }

    await _removeAllExcept(uid, name);
  }

  /// Удаляет из облака все фото пользователя, кроме [keepName]
  static Future<void> _removeAllExcept(String uid, String? keepName) async {
    final storage = Supabase.instance.client.storage.from(_bucket);
    final files = await storage.list(path: uid);
    final old = [
      for (final f in files)
        if (f.name != keepName) '$uid/${f.name}',
    ];
    if (old.isNotEmpty) await storage.remove(old);
  }

  /// Удаляет файлы аватарок с устройства, кроме выбранной
  /// (передай пустую строку, чтобы удалить все).
  static Future<void> cleanupExcept(String keepId) async {
    try {
      final dir = await _photosDir();
      final keep = _safeName(keepId);
      await for (final e in dir.list()) {
        if (e is File && e.uri.pathSegments.last != keep) {
          await e.delete();
        }
      }
    } catch (_) {
      // не критично: лишний файл просто останется
    }
  }
}