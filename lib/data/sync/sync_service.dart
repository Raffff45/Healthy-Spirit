import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient, SignOutScope;

import '../../core/utils/avatar_photo_store.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';

/// Синхронизация локальной базы (SQLite) с облаком (Supabase).
///
/// Схема: полная замена данных пользователя.
///  - любое локальное изменение через 2 с отправляется в облако;
///  - при входе и запуске данные из облака заменяют локальные,
///    если нет неотправленных изменений.
class SyncService {
  final AppDatabase db;
  SyncService(this.db);

  static const _pendingKey = 'sync_pending_push';
  static const _nilUuid = '00000000-0000-0000-0000-000000000000';

  SupabaseClient get _client => Supabase.instance.client;

  StreamSubscription<Set<TableUpdate>>? _sub;
  Timer? _debounce;
  bool _active = false;
  bool _applying = false; // идёт запись данных из облака, не реагируем
  bool _pushing = false;
  bool _pushAgain = false;

  /// Первичная синхронизация и подписка на локальные изменения
  Future<void> start() async {
    if (_client.auth.currentUser == null) return;
    try {
      await _initialSync().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Нет сети: работаем с локальными данными, отправим позже
    }
    _listen();
  }

  Future<void> _initialSync() async {
    final prefs = await SharedPreferences.getInstance();

    // Есть неотправленные изменения: сначала отправляем их
    if (prefs.getBool(_pendingKey) ?? false) {
      await push();
      return;
    }

    final remote = await _client.from('profiles').select().maybeSingle();
    if (remote != null) {
      await _pullAll(remote);
    } else if (await _hasLocalProfile()) {
      await push();
    }
  }

  Future<bool> _hasLocalProfile() async {
    final p = await (db.select(db.userProfiles)..limit(1)).getSingleOrNull();
    return p != null;
  }

  // ---------------- Скачивание ----------------

  Future<List<Map<String, dynamic>>> _fetchAll(String table) async {
    const page = 1000;
    final result = <Map<String, dynamic>>[];
    var from = 0;
    while (true) {
      final rows = await _client
          .from(table)
          .select()
          .order('id')
          .range(from, from + page - 1);
      result.addAll(rows);
      if (rows.length < page) break;
      from += page;
    }
    return result;
  }

  Future<void> _pullAll(Map<String, dynamic> p) async {
    final weights = await _fetchAll('weight_entries');
    final meals = await _fetchAll('meal_entries');

    _applying = true;
    try {
      await db.transaction(() async {
        await db.delete(db.mealEntries).go();
        await db.delete(db.weightEntries).go();
        await db.delete(db.userProfiles).go();

        await db.into(db.userProfiles).insert(
              UserProfilesCompanion.insert(
                gender: p['gender'] as String,
                age: (p['age'] as num).toInt(),
                heightCm: (p['height_cm'] as num).toInt(),
                weightKg: (p['weight_kg'] as num).toDouble(),
                targetWeightKg: (p['target_weight_kg'] as num).toDouble(),
                activity: p['activity'] as String,
                goal: p['goal'] as String,
                targetKcal: (p['target_kcal'] as num).toInt(),
                proteinG: (p['protein_g'] as num).toInt(),
                fatG: (p['fat_g'] as num).toInt(),
                carbsG: (p['carbs_g'] as num).toInt(),
                name: Value((p['name'] as String?) ?? ''),
                avatar: Value((p['avatar'] as String?) ?? 'eco'),
              ),
            );

        await db.batch((b) {
          b.insertAll(db.weightEntries, [
            for (final w in weights)
              WeightEntriesCompanion.insert(
                date: DateTime.parse(w['entry_date'] as String).toLocal(),
                weightKg: (w['weight_kg'] as num).toDouble(),
              ),
          ]);
          b.insertAll(db.mealEntries, [
            for (final m in meals)
              MealEntriesCompanion.insert(
                date: DateTime.parse(m['entry_date'] as String).toLocal(),
                mealType: m['meal_type'] as String,
                productId: (m['product_id'] as num).toInt(),
                grams: (m['grams'] as num).toDouble(),
              ),
          ]);
        });
      });
      // Даём событиям изменения таблиц отработать, пока флаг включён
      await Future<void>.delayed(const Duration(milliseconds: 500));
    } finally {
      _applying = false;
    }
  }

  // ---------------- Отправка ----------------

  void _listen() {
    _sub?.cancel();
    _active = true;
    _sub = db
        .tableUpdates(
          TableUpdateQuery.onAllTables(
            [db.userProfiles, db.weightEntries, db.mealEntries],
          ),
        )
        .listen((_) => _onLocalChange());
  }

  Future<void> _onLocalChange() async {
    if (!_active || _applying) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, true);

    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () async {
      try {
        await push();
      } catch (e) {
        // ignore: avoid_print
        print('SYNC PUSH ERROR: $e');
      }
    });
  }

  /// Отправляет локальные данные в облако (с защитой от параллельных запусков)
  Future<void> push() async {
    if (_pushing) {
      _pushAgain = true;
      return;
    }
    _pushing = true;
    try {
      do {
        _pushAgain = false;
        await _pushOnce();
      } while (_pushAgain);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingKey, false);
    } finally {
      _pushing = false;
    }
  }

  Future<void> _pushOnce() async {
    final profile =
        await (db.select(db.userProfiles)..limit(1)).getSingleOrNull();

    if (profile == null) {
      // Локально пусто (например, «Сбросить все данные»): чистим облако
      await _client.from('meal_entries').delete().gte('id', 0);
      await _client.from('weight_entries').delete().gte('id', 0);
      await _client.from('profiles').delete().neq('user_id', _nilUuid);
      try {
        await AvatarPhotoStore.syncRemote('');
      } catch (_) {}
      return;
    }

    // Фото аватарки уходит в Storage; ошибка не должна мешать отправке данных
    try {
      // ignore: avoid_print
      print('AVATAR value: ${profile.avatar}');
      await AvatarPhotoStore.syncRemote(profile.avatar);
    } catch (e) {
      // ignore: avoid_print
      print('AVATAR UPLOAD ERROR: $e');
    }

    final weights = await db.select(db.weightEntries).get();
    final meals = await db.select(db.mealEntries).get();

    await _client.rpc('replace_user_data', params: {
      'p_profile': {
        'gender': profile.gender,
        'age': profile.age,
        'height_cm': profile.heightCm,
        'weight_kg': profile.weightKg,
        'target_weight_kg': profile.targetWeightKg,
        'activity': profile.activity,
        'goal': profile.goal,
        'target_kcal': profile.targetKcal,
        'protein_g': profile.proteinG,
        'fat_g': profile.fatG,
        'carbs_g': profile.carbsG,
        'name': profile.name,
        'avatar': profile.avatar,
      },
      'p_weights': [
        for (final w in weights)
          {
            'date': w.date.toUtc().toIso8601String(),
            'weight_kg': w.weightKg,
          },
      ],
      'p_meals': [
        for (final m in meals)
          {
            'date': m.date.toUtc().toIso8601String(),
            'meal_type': m.mealType,
            'product_id': m.productId,
            'grams': m.grams,
          },
      ],
    });
  }

  // ---------------- Выход ----------------

  /// Выход: отправляет неотправленное, очищает телефон, закрывает сессию
  Future<void> signOutAndClear() async {
    _debounce?.cancel();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_pendingKey) ?? false) {
      try {
        await push();
      } catch (_) {}
    }

    _active = false;
    await _sub?.cancel();
    _sub = null;

    _applying = true;
    try {
      await db.transaction(() async {
        await db.delete(db.mealEntries).go();
        await db.delete(db.weightEntries).go();
        await db.delete(db.userProfiles).go();
      });
      await AvatarPhotoStore.cleanupExcept('');
      await prefs.remove(_pendingKey);
      await _client.auth.signOut(scope: SignOutScope.local);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } finally {
      _applying = false;
    }
  }

  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref.watch(databaseProvider));
  ref.onDispose(service.dispose);
  return service;
});