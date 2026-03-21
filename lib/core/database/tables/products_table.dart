import 'package:drift/drift.dart';

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get name => text()();
  RealColumn get unitPrice => real()();
  IntColumn get unitsPerPackage => integer().nullable()();
  TextColumn get categoryId => text().nullable()();
  BoolColumn get hasReturnablePackaging => boolean().withDefault(const Constant(false))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
