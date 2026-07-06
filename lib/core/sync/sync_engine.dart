import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pocketbase/pocketbase.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../database/local_db.dart';
import '../pocketbase/pocketbase_client.dart';

String _s(Map<String, dynamic> d, String k) => d[k] as String? ?? '';
double _n(Map<String, dynamic> d, String k) => (d[k] as num?)?.toDouble() ?? 0;
bool _b(Map<String, dynamic> d, String k) => d[k] as bool? ?? false;
DateTime _dt(Map<String, dynamic> d, String k) {
  final v = d[k];
  if (v is String && v.isNotEmpty) return DateTime.parse(v);
  return DateTime.now();
}

class SyncEngine {
  final AppDatabase db;
  final PocketBase pb = PocketBaseService.client;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier(SyncStatus.synced);

  SyncEngine(this.db) {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        triggerSync();
      } else {
        statusNotifier.value = SyncStatus.offline;
      }
    });
  }

  Future<File> _getSyncMetadataFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'sync_metadata.json'));
  }

  Future<DateTime> getLastSyncTime(String userId) async {
    try {
      final file = await _getSyncMetadataFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        if (json.containsKey(userId)) {
          return DateTime.parse(json[userId] as String);
        }
      }
    } catch (e) {
      Sentry.captureException(e);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> saveLastSyncTime(String userId, DateTime time) async {
    try {
      final file = await _getSyncMetadataFile();
      Map<String, dynamic> json = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        json = Map<String, dynamic>.from(jsonDecode(content) as Map);
      }
      json[userId] = time.toIso8601String();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      Sentry.captureException(e);
    }
  }

  Future<RecordModel?> _maybeGetOne(String collection, String id) async {
    try {
      return await pb.collection(collection).getOne(id);
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      return null;
    }
  }

  Future<bool> _upsert(String collection, String id, Map<String, dynamic> body) async {
    try {
      await pb.collection(collection).update(id, body: body);
      return true;
    } catch (_) {
      try {
        await pb.collection(collection).create(body: {...body, 'id': id});
        return true;
      } catch (e) {
        Sentry.captureException(e);
        return false;
      }
    }
  }

  Future<void> triggerSync() async {
    if (_isSyncing) return;

    final connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults.every((r) => r == ConnectivityResult.none)) {
      statusNotifier.value = SyncStatus.offline;
      return;
    }

    final userId = PocketBaseService.currentUser?.id;
    if (userId == null) {
      statusNotifier.value = SyncStatus.synced;
      return;
    }

    _isSyncing = true;
    statusNotifier.value = SyncStatus.syncing;

    try {
      // Refresh auth token to ensure it's valid before any API calls
      try {
        await pb.collection('users').authRefresh();
      } catch (e) {
        Sentry.captureException(e);
      }

      await _pushDeletes(userId);
      await _pushUpserts(userId);
      await _pullPhase(userId);

      statusNotifier.value = SyncStatus.synced;
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      statusNotifier.value = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushDeletes(String userId) async {
    final dirtyTxns = await db.getDirtyTransactions(userId);
    for (final txn in dirtyTxns.where((t) => t.isDeleted)) {
      try {
        await pb.collection('transactions').delete(txn.id);
      } catch (e) {
        if (e is ClientException && e.statusCode != 404) {
          Sentry.captureException(e);
        }
      }
      await db.hardDeleteTransaction(txn.id);
    }

    final dirtyContacts = await db.getDirtyContacts(userId);
    for (final contact in dirtyContacts.where((t) => t.isDeleted)) {
      try {
        await pb.collection('contacts').delete(contact.id);
      } catch (e) {
        if (e is ClientException && e.statusCode != 404) {
          Sentry.captureException(e);
        }
      }
      await db.hardDeleteContact(contact.id);
    }

    final dirtyExpenses = await db.getDirtyExpenses(userId);
    for (final exp in dirtyExpenses.where((t) => t.isDeleted)) {
      try {
        await pb.collection('expenses').delete(exp.id);
      } catch (e) {
        if (e is ClientException && e.statusCode != 404) {
          Sentry.captureException(e);
        }
      }
      await db.hardDeleteExpense(exp.id);
    }

    final dirtyExpenseCategories = await db.getDirtyExpenseCategories(userId);
    for (final cat in dirtyExpenseCategories.where((t) => t.isDeleted)) {
      try {
        await pb.collection('expense_categories').delete(cat.id);
      } catch (e) {
        if (e is ClientException && e.statusCode != 404) {
          Sentry.captureException(e);
        }
      }
      await db.hardDeleteExpenseCategory(cat.id);
    }
  }

  Future<void> _pushUpserts(String userId) async {
    final dirtyContacts = await db.getDirtyContacts(userId);
    for (final contact in dirtyContacts.where((t) => !t.isDeleted)) {
      if (await _upsert('contacts', contact.id, {
        'user_id': contact.userId,
        'name': contact.name,
        'phone': contact.phone,
        'created_at': contact.createdAt.toUtc().toIso8601String(),
        'updated_at': contact.updatedAt.toUtc().toIso8601String(),
        'is_deleted': false,
        'is_archived': contact.isArchived,
      })) {
        await db.upsertContact(contact.copyWith(isDirty: false));
      }
    }

    final dirtyTxns = await db.getDirtyTransactions(userId);
    for (final txn in dirtyTxns.where((t) => !t.isDeleted)) {
      if (await _upsert('transactions', txn.id, {
        'contact_id': txn.contactId,
        'user_id': txn.userId,
        'amount': txn.amount,
        'type': txn.type,
        'description': txn.description,
        'date': txn.date.toIso8601String().split('T')[0],
        'created_at': txn.createdAt.toUtc().toIso8601String(),
        'updated_at': txn.updatedAt.toUtc().toIso8601String(),
        'is_deleted': false,
      })) {
        await db.upsertTransaction(txn.copyWith(isDirty: false));
      }
    }

    final dirtyExpenseCategories = await db.getDirtyExpenseCategories(userId);
    for (final cat in dirtyExpenseCategories.where((t) => !t.isDeleted)) {
      List<String> subs = [];
      try {
        final List<dynamic> parsed = jsonDecode(cat.subCategories);
        subs = parsed.map((e) => e.toString()).toList();
      } catch (e, stack) {
        Sentry.captureException(e, stackTrace: stack);
      }

      if (await _upsert('expense_categories', cat.id, {
        'user_id': cat.userId,
        'name': cat.name,
        'icon': cat.icon,
        'color': cat.color,
        'sub_categories': subs,
        'created_at': cat.createdAt.toUtc().toIso8601String(),
        'updated_at': cat.updatedAt.toUtc().toIso8601String(),
        'is_deleted': false,
      })) {
        await db.upsertExpenseCategory(cat.copyWith(isDirty: false));
      }
    }

    final dirtyExpenses = await db.getDirtyExpenses(userId);
    for (final exp in dirtyExpenses.where((t) => !t.isDeleted)) {
      if (await _upsert('expenses', exp.id, {
        'user_id': exp.userId,
        'category_id': exp.categoryId,
        'sub_category': exp.subCategory,
        'amount': exp.amount,
        'remarks': exp.remarks,
        'date': exp.date.toIso8601String().split('T')[0],
        'created_at': exp.createdAt.toUtc().toIso8601String(),
        'updated_at': exp.updatedAt.toUtc().toIso8601String(),
        'is_deleted': false,
      })) {
        await db.upsertExpense(exp.copyWith(isDirty: false));
      }
    }
  }

  Future<void> _pullPhase(String userId) async {
    final lastSync = await getLastSyncTime(userId);
    DateTime newLastSync = lastSync;

    final contactsResponse = await pb.collection('contacts').getFullList(
      filter: 'user_id="$userId" && updated_at>"${lastSync.toIso8601String()}"',
    );

    for (final remote in contactsResponse) {
      final d = remote.data;
      final id = remote.id;
      final remoteUpdatedAt = _dt(d, 'updated_at');
      final isRemoteDeleted = _b(d, 'is_deleted');

      if (remoteUpdatedAt.isAfter(newLastSync)) {
        newLastSync = remoteUpdatedAt;
      }

      final local = await db.getContactById(id);
      if (local != null) {
        if (local.isDirty) {
          if (remoteUpdatedAt.isAfter(local.updatedAt)) {
            if (isRemoteDeleted) {
              await db.hardDeleteContact(id);
            } else {
              await db.upsertContact(Contact(
                id: id, userId: userId, name: _s(d, 'name'), phone: _s(d, 'phone'),
                createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
                isDirty: false, isDeleted: false, isArchived: _b(d, 'is_archived'),
              ));
            }
          } else {
          }
        } else {
          if (isRemoteDeleted) {
            await db.hardDeleteContact(id);
          } else {
            await db.upsertContact(Contact(
              id: id, userId: userId, name: _s(d, 'name'), phone: _s(d, 'phone'),
              createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
              isDirty: false, isDeleted: false, isArchived: _b(d, 'is_archived'),
            ));
          }
        }
      } else if (!isRemoteDeleted) {
        await db.upsertContact(Contact(
          id: id, userId: userId, name: _s(d, 'name'), phone: _s(d, 'phone'),
          createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
          isDirty: false, isDeleted: false, isArchived: _b(d, 'is_archived'),
        ));
      }
    }

    final txnsResponse = await pb.collection('transactions').getFullList(
      filter: 'user_id="$userId" && updated_at>"${lastSync.toIso8601String()}"',
    );

    for (final remote in txnsResponse) {
      final d = remote.data;
      final id = remote.id;
      final remoteUpdatedAt = _dt(d, 'updated_at');
      final isRemoteDeleted = _b(d, 'is_deleted');

      if (remoteUpdatedAt.isAfter(newLastSync)) {
        newLastSync = remoteUpdatedAt;
      }

      final contactId = _s(d, 'contact_id');
      final localContact = await db.getContactById(contactId);
      if (localContact == null) {
        final cRes = await _maybeGetOne('contacts', contactId);
        if (cRes != null) {
          await db.upsertContact(Contact(
            id: contactId, userId: userId, name: _s(cRes.data, 'name'), phone: _s(cRes.data, 'phone'),
            createdAt: _dt(cRes.data, 'created_at'), updatedAt: _dt(cRes.data, 'updated_at'),
            isDirty: false, isDeleted: false, isArchived: _b(cRes.data, 'is_archived'),
          ));
        } else {
          Sentry.captureException(Exception('Failed to fetch contact $contactId for transaction'));
          continue;
        }
      }

      final localTxn = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (localTxn != null) {
        if (localTxn.isDirty) {
          if (remoteUpdatedAt.isAfter(localTxn.updatedAt)) {
            if (isRemoteDeleted) {
              await db.hardDeleteTransaction(id);
            } else {
              await db.upsertTransaction(TransactionModel(
                id: id, contactId: contactId, userId: userId,
                amount: _n(d, 'amount'), type: _s(d, 'type'), description: _s(d, 'description'),
                date: _dt(d, 'date'), createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
                isDirty: false, isDeleted: false,
              ));
            }
          } else {
          }
        } else {
          if (isRemoteDeleted) {
            await db.hardDeleteTransaction(id);
          } else {
            await db.upsertTransaction(TransactionModel(
              id: id, contactId: contactId, userId: userId,
              amount: _n(d, 'amount'), type: _s(d, 'type'), description: _s(d, 'description'),
              date: _dt(d, 'date'), createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
              isDirty: false, isDeleted: false,
            ));
          }
        }
      } else if (!isRemoteDeleted) {
        await db.upsertTransaction(TransactionModel(
          id: id, contactId: contactId, userId: userId,
          amount: _n(d, 'amount'), type: _s(d, 'type'), description: _s(d, 'description'),
          date: _dt(d, 'date'), createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
          isDirty: false, isDeleted: false,
        ));
      }
    }

    final expenseCategoriesResponse = await pb.collection('expense_categories').getFullList(
      filter: 'user_id="$userId" && updated_at>"${lastSync.toIso8601String()}"',
    );

    for (final remote in expenseCategoriesResponse) {
      final d = remote.data;
      final id = remote.id;
      final remoteUpdatedAt = _dt(d, 'updated_at');
      final isRemoteDeleted = _b(d, 'is_deleted');

      if (remoteUpdatedAt.isAfter(newLastSync)) {
        newLastSync = remoteUpdatedAt;
      }

      final subs = (d['sub_categories'] as List<dynamic>?) ?? [];
      final subCategoriesJson = jsonEncode(subs.map((e) => e.toString()).toList());

      final local = await db.getExpenseCategoryById(id);
      if (local != null) {
        if (local.isDirty) {
          if (remoteUpdatedAt.isAfter(local.updatedAt)) {
            if (isRemoteDeleted) {
              await db.hardDeleteExpenseCategory(id);
            } else {
              await db.upsertExpenseCategory(ExpenseCategory(
                id: id, userId: userId, name: _s(d, 'name'),
                icon: _s(d, 'icon'), color: _s(d, 'color'),
                subCategories: subCategoriesJson,
                createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
                isDirty: false, isDeleted: false,
              ));
            }
          } else {
          }
        } else {
          if (isRemoteDeleted) {
            await db.hardDeleteExpenseCategory(id);
          } else {
            await db.upsertExpenseCategory(ExpenseCategory(
              id: id, userId: userId, name: _s(d, 'name'),
              icon: _s(d, 'icon'), color: _s(d, 'color'),
              subCategories: subCategoriesJson,
              createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
              isDirty: false, isDeleted: false,
            ));
          }
        }
      } else if (!isRemoteDeleted) {
        await db.upsertExpenseCategory(ExpenseCategory(
          id: id, userId: userId, name: _s(d, 'name'),
          icon: _s(d, 'icon'), color: _s(d, 'color'),
          subCategories: subCategoriesJson,
          createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
          isDirty: false, isDeleted: false,
        ));
      }
    }

    final expensesResponse = await pb.collection('expenses').getFullList(
      filter: 'user_id="$userId" && updated_at>"${lastSync.toIso8601String()}"',
    );

    for (final remote in expensesResponse) {
      final d = remote.data;
      final id = remote.id;
      final remoteUpdatedAt = _dt(d, 'updated_at');
      final isRemoteDeleted = _b(d, 'is_deleted');

      if (remoteUpdatedAt.isAfter(newLastSync)) {
        newLastSync = remoteUpdatedAt;
      }

      final categoryId = _s(d, 'category_id');
      final localCategory = await db.getExpenseCategoryById(categoryId);
      if (localCategory == null) {
        final catRes = await _maybeGetOne('expense_categories', categoryId);
        if (catRes != null) {
          final subs = (catRes.data['sub_categories'] as List<dynamic>?) ?? [];
          await db.upsertExpenseCategory(ExpenseCategory(
            id: categoryId, userId: userId, name: _s(catRes.data, 'name'),
            icon: _s(catRes.data, 'icon'), color: _s(catRes.data, 'color'),
            subCategories: jsonEncode(subs.map((e) => e.toString()).toList()),
            createdAt: _dt(catRes.data, 'created_at'), updatedAt: _dt(catRes.data, 'updated_at'),
            isDirty: false, isDeleted: false,
          ));
        } else {
          Sentry.captureException(Exception('Failed to pull parent category for expense'));
          continue;
        }
      }

      final localExp = await (db.select(db.expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (localExp != null) {
        if (localExp.isDirty) {
          if (remoteUpdatedAt.isAfter(localExp.updatedAt)) {
            if (isRemoteDeleted) {
              await db.hardDeleteExpense(id);
            } else {
              await db.upsertExpense(Expense(
                id: id, userId: userId, categoryId: categoryId,
                subCategory: _s(d, 'sub_category'), amount: _n(d, 'amount'),
                remarks: _s(d, 'remarks'), date: _dt(d, 'date'),
                createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
                isDirty: false, isDeleted: false,
              ));
            }
          } else {
          }
        } else {
          if (isRemoteDeleted) {
            await db.hardDeleteExpense(id);
          } else {
            await db.upsertExpense(Expense(
              id: id, userId: userId, categoryId: categoryId,
              subCategory: _s(d, 'sub_category'), amount: _n(d, 'amount'),
              remarks: _s(d, 'remarks'), date: _dt(d, 'date'),
              createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
              isDirty: false, isDeleted: false,
            ));
          }
        }
      } else if (!isRemoteDeleted) {
        await db.upsertExpense(Expense(
          id: id, userId: userId, categoryId: categoryId,
          subCategory: _s(d, 'sub_category'), amount: _n(d, 'amount'),
          remarks: _s(d, 'remarks'), date: _dt(d, 'date'),
          createdAt: _dt(d, 'created_at'), updatedAt: remoteUpdatedAt,
          isDirty: false, isDeleted: false,
        ));
      }
    }

    if (newLastSync.isAfter(lastSync)) {
      await saveLastSyncTime(userId, newLastSync);
    }
  }
}

enum SyncStatus {
  synced,
  syncing,
  offline,
  error
}
