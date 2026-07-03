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

@DataClassName('ExpenseCategory')
class ExpenseCategories extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get icon => text()();
  TextColumn get color => text()();
  TextColumn get subCategories => text()(); // JSON list of sub-categories
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Expense')
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().references(ExpenseCategories, #id, onDelete: KeyAction.cascade)();
  TextColumn get subCategory => text().withDefault(const Constant('General'))();
  RealColumn get amount => real()();
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Contacts, Transactions, ExpenseCategories, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2; // Incremented schema version for migrations

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            // Create the new tables for the expense tracker
            await migrator.createTable(expenseCategories);
            await migrator.createTable(expenses);
          }
        },
      );

  // === Contacts Queries ===
  Stream<List<Contact>> watchContacts(String userId) {
    return (select(contacts)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<Contact?> getContactById(String id) {
    return (select(contacts)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> getActiveTransactionsForContact(String contactId) async {
    final rows = await (select(transactions)
          ..where((t) => t.contactId.equals(contactId) & t.isDeleted.equals(false)))
        .get();
    return rows.length;
  }

  Future<void> upsertContact(Contact contact) async {
    await into(contacts).insertOnConflictUpdate(contact);
  }

  Future<void> softDeleteContact(String id) async {
    await (update(contacts)..where((t) => t.id.equals(id))).write(
      const ContactsCompanion(
        isDeleted: Value(true),
        isDirty: Value(true),
      ),
    );
  }

  Future<void> hardDeleteContact(String id) async {
    await (delete(contacts)..where((t) => t.id.equals(id))).go();
  }

  Future<List<Contact>> getDirtyContacts(String userId) {
    return (select(contacts)..where((t) => t.userId.equals(userId) & t.isDirty.equals(true))).get();
  }

  // === Transactions Queries ===
  Stream<List<TransactionModel>> watchTransactionsForContact(String contactId) {
    return (select(transactions)
          ..where((t) => t.contactId.equals(contactId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<TransactionModel>> watchAllTransactions(String userId) {
    return (select(transactions)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false)))
        .watch();
  }

  Future<void> upsertTransaction(TransactionModel transaction) async {
    await into(transactions).insertOnConflictUpdate(transaction);
  }

  Future<void> softDeleteTransaction(String id) async {
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      const TransactionsCompanion(
        isDeleted: Value(true),
        isDirty: Value(true),
      ),
    );
  }

  Future<void> hardDeleteTransaction(String id) async {
    await (delete(transactions)..where((t) => t.id.equals(id))).go();
  }

  Future<List<TransactionModel>> getDirtyTransactions(String userId) {
    return (select(transactions)..where((t) => t.userId.equals(userId) & t.isDirty.equals(true))).get();
  }

  // === Expense Categories Queries ===
  Stream<List<ExpenseCategory>> watchExpenseCategories(String userId) {
    return (select(expenseCategories)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<ExpenseCategory?> getExpenseCategoryById(String id) {
    return (select(expenseCategories)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> getActiveExpensesForCategory(String categoryId) async {
    final rows = await (select(expenses)
          ..where((t) => t.categoryId.equals(categoryId) & t.isDeleted.equals(false)))
        .get();
    return rows.length;
  }

  Future<void> upsertExpenseCategory(ExpenseCategory cat) async {
    await into(expenseCategories).insertOnConflictUpdate(cat);
  }

  Future<void> softDeleteExpenseCategory(String id) async {
    await (update(expenseCategories)..where((t) => t.id.equals(id))).write(
      const ExpenseCategoriesCompanion(
        isDeleted: Value(true),
        isDirty: Value(true),
      ),
    );
  }

  Future<void> hardDeleteExpenseCategory(String id) async {
    await (delete(expenseCategories)..where((t) => t.id.equals(id))).go();
  }

  Future<List<ExpenseCategory>> getDirtyExpenseCategories(String userId) {
    return (select(expenseCategories)..where((t) => t.userId.equals(userId) & t.isDirty.equals(true))).get();
  }

  // === Expenses Queries ===
  Stream<List<Expense>> watchExpenses(String userId) {
    return (select(expenses)
          ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<void> upsertExpense(Expense exp) async {
    await into(expenses).insertOnConflictUpdate(exp);
  }

  Future<void> softDeleteExpense(String id) async {
    await (update(expenses)..where((t) => t.id.equals(id))).write(
      const ExpensesCompanion(
        isDeleted: Value(true),
        isDirty: Value(true),
      ),
    );
  }

  Future<void> hardDeleteExpense(String id) async {
    await (delete(expenses)..where((t) => t.id.equals(id))).go();
  }

  Future<List<Expense>> getDirtyExpenses(String userId) {
    return (select(expenses)..where((t) => t.userId.equals(userId) & t.isDirty.equals(true))).get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'kitnabacha.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      setup: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  });
}
