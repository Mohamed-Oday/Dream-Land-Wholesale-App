import 'package:drift/drift.dart';

class AppConfigEntries extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'app_config';
}
