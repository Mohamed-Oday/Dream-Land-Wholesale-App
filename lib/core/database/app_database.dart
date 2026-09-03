import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/users_table.dart';
import 'tables/stores_table.dart';
import 'tables/products_table.dart';
import 'tables/orders_table.dart';
import 'tables/order_lines_table.dart';
import 'tables/payments_table.dart';
import 'tables/package_logs_table.dart';
import 'tables/driver_locations_table.dart';
import 'tables/app_config_table.dart';
import 'tables/sync_queue_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Users,
  Stores,
  Products,
  Orders,
  OrderLines,
  Payments,
  PackageLogs,
  DriverLocations,
  AppConfigEntries,
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static AppDatabase? _instance;

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  @override
  int get schemaVersion => 2;

  @override
    MigrationStrategy get migration {
      return MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
                  if (from < 2) {
                    // Migration v1 -> v2: Add new columns for Features 1 and 3
                    await m.addColumn(products, products.sellByPiece);
                    await m.addColumn(orderLines, orderLines.soldByPiece);
                    await m.addColumn(orderLines, orderLines.piecesQuantity);
                    await m.addColumn(orders, orders.paymentStatus);
                    await m.addColumn(orders, orders.paidAmount);
                    await m.addColumn(orders, orders.paidAt);
                    await m.addColumn(payments, payments.orderId);
                  }
                },
      );
    }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tawzii.db'));
    return NativeDatabase.createInBackground(file);
  });
}
