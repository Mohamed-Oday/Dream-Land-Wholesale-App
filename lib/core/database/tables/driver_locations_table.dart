import 'package:drift/drift.dart';

class DriverLocations extends Table {
  TextColumn get id => text()();
  TextColumn get driverId => text()();
  TextColumn get businessId => text()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
