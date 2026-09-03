import 'package:drift/drift.dart';

class OrderLines extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  TextColumn get productId => text()();
  IntColumn get quantity => integer()();
  RealColumn get unitPrice => real()();
  IntColumn get packagesCount => integer().nullable()();
  RealColumn get lineTotal => real().withDefault(const Constant(0.0))();
  BoolColumn get soldByPiece => boolean().withDefault(const Constant(false))();
  IntColumn get piecesQuantity => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
