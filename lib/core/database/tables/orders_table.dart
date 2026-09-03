import 'package:drift/drift.dart';

class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get storeId => text()();
  TextColumn get driverId => text()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxPercentage => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  TextColumn get discountStatus => text().withDefault(const Constant('none'))();
  TextColumn get discountApprovedBy => text().nullable()();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('created'))();
  TextColumn get paymentStatus => text().withDefault(const Constant('unpaid'))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get paidAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
