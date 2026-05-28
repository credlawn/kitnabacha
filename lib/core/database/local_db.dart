import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'local_db.g.dart';

@DataClassName('Contact')
class Contacts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionModel')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get contactId => text().references(Contacts, #id, onDelete: KeyAction.cascade)();
  TextColumn get userId => text()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'give' (Udhaar Diya), 'take' (Udhaar Liya), 'receive' (Payment received), 'pay' (Payment made)
  TextColumn get description => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Contacts, Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;

  // Stream of all non-deleted contacts
  Stream<List<Contact>> watchContacts(String userId) {
    return (select(contacts)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  // Stream of all transactions for a specific contact
  Stream<List<TransactionModel>> watchTransactionsForContact(String contactId) {
    return (select(transactions)
          ..where((t) => t.contactId.equals(contactId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  // Stream of all non-deleted transactions for a user (useful for dashboard statistics)
  Stream<List<TransactionModel>> watchAllTransactions(String userId) {
    return (select(transactions)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false)))
        .watch();
  }

  // Get single contact by ID
  Future<Contact?> getContactById(String id) {
    return (select(contacts)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Upsert contact
  Future<void> upsertContact(Contact contact) async {
    await into(contacts).insertOnConflictUpdate(contact);
  }

  // Upsert transaction
  Future<void> upsertTransaction(TransactionModel transaction) async {
    await into(transactions).insertOnConflictUpdate(transaction);
  }

  // Soft delete a contact
  Future<void> softDeleteContact(String id) async {
    await (update(contacts)..where((t) => t.id.equals(id))).write(
      const ContactsCompanion(
        isDeleted: Value(true),
        isDirty: Value(true),
      ),
    );
    // Also soft-delete all transactions of this contact
    await (update(transactions)..where((t) => t.contactId.equals(id))).write(
      const TransactionsCompanion(
        isDeleted: Value(true),
        isDirty: Value(true),
      ),
    );
  }

  // Soft delete a transaction
  Future<void> softDeleteTransaction(String id) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      const TransactionsCompanion(
        isDeleted: Value(true),
        isDirty: Value(true),
      ),
    );
  }

  // Permanently delete a contact (used by sync engine after deletion confirmation from server)
  Future<void> hardDeleteContact(String id) async {
    await (delete(contacts)..where((t) => t.id.equals(id))).go();
  }

  // Permanently delete a transaction (used by sync engine after deletion confirmation from server)
  Future<void> hardDeleteTransaction(String id) async {
    await (delete(transactions)..where((t) => t.id.equals(id))).go();
  }

  // Get all dirty contacts
  Future<List<Contact>> getDirtyContacts(String userId) {
    return (select(contacts)..where((t) => t.userId.equals(userId) & t.isDirty.equals(true))).get();
  }

  // Get all dirty transactions
  Future<List<TransactionModel>> getDirtyTransactions(String userId) {
    return (select(transactions)..where((t) => t.userId.equals(userId) & t.isDirty.equals(true))).get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kitnabacha.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
