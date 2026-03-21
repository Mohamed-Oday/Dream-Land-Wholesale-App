import 'package:drift/drift.dart';

class PackageLogs extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get storeId => text()();
  TextColumn get driverId => text()();
  TextColumn get productId => text()();
  TextColumn get orderId => text().nullable()();
  IntColumn get given => integer().withDefault(const Constant(0))();
  IntColumn get collected => integer().withDefault(const Constant(0))();
  IntColumn get balanceAfter => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
