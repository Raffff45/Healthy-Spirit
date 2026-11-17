import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';

class ProductRepository {
  final AppDatabase db;
  ProductRepository(this.db);

  Stream<List<Product>> watchAll() {
    return (db.select(db.products)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(databaseProvider));
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchAll();
});