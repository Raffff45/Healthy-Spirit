import '../../data/models/gender.dart';

/// Пути к картинкам из папки assets/images/
class AppAssets {
  static const grass1 = 'assets/images/grass.png';
  static const grass2 = 'assets/images/grass2.png';
  static const grass3 = 'assets/images/grass3.png';
  static const man = 'assets/images/man.png';
  static const woman = 'assets/images/woman.png';

  static const all = <String>[grass1, grass2, grass3, man, woman];

  /// Фон, который соответствует выбранному полу.
  static String forGender(Gender gender) =>
      gender == Gender.female ? woman : man;
}