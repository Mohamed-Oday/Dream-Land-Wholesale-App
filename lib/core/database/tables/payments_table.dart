import 'package:drift/drift.dart';

class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get storeId => text()();
  TextColumn get driverId => text()();
  RealColumn get amount => real()();
  TextColumn get method => text().withDefault(const Constant('cash'))();
  RealColumn get previousBalance => real()();
  RealColumn get newBalance => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
