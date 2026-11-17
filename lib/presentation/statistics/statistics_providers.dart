import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/profile_repository.dart';

/// История изменения веса
final weightHistoryProvider = StreamProvider<List<WeightEntry>>((ref) {
  return ref.watch(profileRepositoryProvider).watchWeights();
});