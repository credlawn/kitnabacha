import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgeo/core/database/local_db.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  test('Insert and query a contact successfully', () async {
    final contact = Contact(
      id: 'c1',
      userId: 'user_xyz',
      name: 'R Ramesh',
      phone: '9876543210',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDirty: true,
      isDeleted: false,
      isArchived: false,
    );

    await db.upsertContact(contact);

    final retrieved = await db.getContactById('c1');
    expect(retrieved, isNotNull);
    expect(retrieved!.name, 'R Ramesh');
    expect(retrieved.phone, '9876543210');
  });

  test('Verify stream of active contacts excludes soft-deleted items', () async {
    final c1 = Contact(
      id: 'c1',
      userId: 'user_xyz',
      name: 'Amir Khan',
      phone: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDirty: true,
      isDeleted: false,
      isArchived: false,
    );

    final c2 = Contact(
      id: 'c2',
      userId: 'user_xyz',
      name: 'Salman Khan',
      phone: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDirty: true,
      isDeleted: true,
      isArchived: false,
    );

    await db.upsertContact(c1);
    await db.upsertContact(c2);

    final activeContactsList = await db.watchContacts('user_xyz').first;
    expect(activeContactsList.length, 1);
    expect(activeContactsList.first.id, 'c1');
  });

  test('Verify transaction stream displays under parent contact', () async {
    final contact = Contact(
      id: 'c_abc',
      userId: 'user_123',
      name: 'Suresh Kumar',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDirty: false,
      isDeleted: false,
      isArchived: false,
    );

    final now = DateTime.now();
    final t1 = TransactionModel(
      id: 't_1',
      contactId: 'c_abc',
      userId: 'user_123',
      amount: 500.0,
      type: 'give',
      date: now.subtract(const Duration(hours: 2)),
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
      isDirty: true,
      isDeleted: false,
    );

    final t2 = TransactionModel(
      id: 't_2',
      contactId: 'c_abc',
      userId: 'user_123',
      amount: 150.0,
      type: 'receive',
      date: now,
      createdAt: now,
      updatedAt: now,
      isDirty: true,
      isDeleted: false,
    );

    await db.upsertContact(contact);
    await db.upsertTransaction(t1);
    await db.upsertTransaction(t2);

    final list = await db.watchTransactionsForContact('c_abc').first;
    expect(list.length, 2);
    expect(list[0].amount, 150.0);
    expect(list[1].amount, 500.0);
  });

  test('Verify soft delete excludes transactions from active list', () async {
    final contact = Contact(
      id: 'c_del',
      userId: 'user_123',
      name: 'Rajesh',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDirty: false,
      isDeleted: false,
      isArchived: false,
    );

    final txn = TransactionModel(
      id: 't_del',
      contactId: 'c_del',
      userId: 'user_123',
      amount: 1000.0,
      type: 'give',
      date: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDirty: false,
      isDeleted: false,
    );

    await db.upsertContact(contact);
    await db.upsertTransaction(txn);

    var contacts = await db.watchContacts('user_123').first;
    var txns = await db.watchTransactionsForContact('c_del').first;
    expect(contacts.length, 1);
    expect(txns.length, 1);

    await db.softDeleteContact('c_del');

    contacts = await db.watchContacts('user_123').first;
    expect(contacts.isEmpty, true);

    final dirtyContacts = await db.getDirtyContacts('user_123');
    expect(dirtyContacts.length, 1);
    expect(dirtyContacts.first.isDeleted, true);
  });
}
