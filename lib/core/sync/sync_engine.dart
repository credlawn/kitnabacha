import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_db.dart';
import '../supabase/supabase_client.dart';

class SyncEngine {
  final AppDatabase db;
  final SupabaseClient supabase = SupabaseService.client;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier(SyncStatus.synced);

  SyncEngine(this.db) {
    // Listen to network changes and auto-trigger sync when online
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        triggerSync();
      } else {
        statusNotifier.value = SyncStatus.offline;
      }
    });
  }

  // Get path to store sync metadata
  Future<File> _getSyncMetadataFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'sync_metadata.json'));
  }

  // Get last sync timestamp
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
      debugPrint('Error reading sync metadata: $e');
    }
    return DateTime.fromMillisecondsSinceEpoch(0); // Epoch (1970) if never synced
  }

  // Save last sync timestamp
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
      debugPrint('Error saving sync metadata: $e');
    }
  }

  // Validate that a string is a proper UUID (v4 format)
  static final _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  bool _isValidUuid(String id) => _uuidRegex.hasMatch(id);

  // Primary method to trigger synchronization
  Future<void> triggerSync() async {
    if (_isSyncing) return;
    
    // Check network connectivity first
    final connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults.every((r) => r == ConnectivityResult.none)) {
      statusNotifier.value = SyncStatus.offline;
      return;
    }

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      statusNotifier.value = SyncStatus.synced; // Nothing to sync if guest/logged out
      return;
    }

    _isSyncing = true;
    statusNotifier.value = SyncStatus.syncing;
    debugPrint('=== Sync Started ===');

    try {
      // 1. Push local changes to Supabase
      await _pushPhase(userId);

      // 2. Pull remote changes from Supabase
      await _pullPhase(userId);

      statusNotifier.value = SyncStatus.synced;
      debugPrint('=== Sync Succeeded ===');
    } catch (e, stack) {
      debugPrint('Sync failed: $e\n$stack');
      statusNotifier.value = SyncStatus.error;
    } finally {
      _isSyncing = false;
    }
  }

  // Push Phase: Send locally modified data to Supabase
  Future<void> _pushPhase(String userId) async {
    debugPrint('Push Phase: Syncing contacts...');
    // Push Contacts
    final dirtyContacts = await db.getDirtyContacts(userId);
    for (final contact in dirtyContacts) {
      // Skip & hard-delete any legacy rows with non-UUID ids
      if (!_isValidUuid(contact.id)) {
        debugPrint('Cleaning up legacy contact with invalid id: ${contact.id}');
        await db.hardDeleteContact(contact.id);
        continue;
      }
      if (contact.isDeleted) {
        await supabase.from('contacts').delete().eq('id', contact.id);
        await db.hardDeleteContact(contact.id);
        debugPrint('Pushed deleted contact: ${contact.id}');
      } else {
        await supabase.from('contacts').upsert({
          'id': contact.id,
          'user_id': contact.userId,
          'name': contact.name,
          'phone': contact.phone,
          'created_at': contact.createdAt.toIso8601String(),
          'updated_at': contact.updatedAt.toIso8601String(),
          'is_deleted': false,
        });
        await db.upsertContact(contact.copyWith(isDirty: false));
        debugPrint('Pushed upserted contact: ${contact.name}');
      }
    }

    debugPrint('Push Phase: Syncing transactions...');
    // Push Transactions
    final dirtyTxns = await db.getDirtyTransactions(userId);
    for (final txn in dirtyTxns) {
      // Skip & hard-delete any legacy rows with non-UUID ids (e.g. 'expense_categories_meta')
      if (!_isValidUuid(txn.id) || !_isValidUuid(txn.contactId)) {
        debugPrint('Cleaning up legacy transaction with invalid id: ${txn.id}');
        await db.hardDeleteTransaction(txn.id);
        continue;
      }
      if (txn.isDeleted) {
        await supabase.from('transactions').delete().eq('id', txn.id);
        await db.hardDeleteTransaction(txn.id);
        debugPrint('Pushed deleted transaction: ${txn.id}');
      } else {
        await supabase.from('transactions').upsert({
          'id': txn.id,
          'contact_id': txn.contactId,
          'user_id': txn.userId,
          'amount': txn.amount,
          'type': txn.type,
          'description': txn.description,
          'date': txn.date.toIso8601String().split('T')[0],
          'created_at': txn.createdAt.toIso8601String(),
          'updated_at': txn.updatedAt.toIso8601String(),
          'is_deleted': false,
        });
        await db.upsertTransaction(txn.copyWith(isDirty: false));
        debugPrint('Pushed upserted transaction: ${txn.id}');
      }
    }

    debugPrint('Push Phase: Syncing expense categories...');
    // Push Expense Categories
    final dirtyExpenseCategories = await db.getDirtyExpenseCategories(userId);
    for (final cat in dirtyExpenseCategories) {
      if (cat.isDeleted) {
        await supabase.from('expense_categories').delete().eq('id', cat.id);
        await db.hardDeleteExpenseCategory(cat.id);
        debugPrint('Pushed deleted expense category: ${cat.id}');
      } else {
        List<String> subs = [];
        try {
          final List<dynamic> parsed = jsonDecode(cat.subCategories);
          subs = parsed.map((e) => e.toString()).toList();
        } catch (_) {}

        await supabase.from('expense_categories').upsert({
          'id': cat.id,
          'user_id': cat.userId,
          'name': cat.name,
          'icon': cat.icon,
          'color': cat.color,
          'sub_categories': subs,
          'created_at': cat.createdAt.toIso8601String(),
          'updated_at': cat.updatedAt.toIso8601String(),
          'is_deleted': false,
        });
        await db.upsertExpenseCategory(cat.copyWith(isDirty: false));
        debugPrint('Pushed upserted expense category: ${cat.name}');
      }
    }

    debugPrint('Push Phase: Syncing expenses...');
    // Push Expenses
    final dirtyExpenses = await db.getDirtyExpenses(userId);
    for (final exp in dirtyExpenses) {
      if (exp.isDeleted) {
        await supabase.from('expenses').delete().eq('id', exp.id);
        await db.hardDeleteExpense(exp.id);
        debugPrint('Pushed deleted expense: ${exp.id}');
      } else {
        await supabase.from('expenses').upsert({
          'id': exp.id,
          'user_id': exp.userId,
          'category_id': exp.categoryId,
          'sub_category': exp.subCategory,
          'amount': exp.amount,
          'remarks': exp.remarks,
          'date': exp.date.toIso8601String(),
          'created_at': exp.createdAt.toIso8601String(),
          'updated_at': exp.updatedAt.toIso8601String(),
          'is_deleted': false,
        });
        await db.upsertExpense(exp.copyWith(isDirty: false));
        debugPrint('Pushed upserted expense: ${exp.id}');
      }
    }
  }

  // Pull Phase: Get updates from Supabase since last sync timestamp
  Future<void> _pullPhase(String userId) async {
    final lastSync = await getLastSyncTime(userId);
    DateTime newLastSync = lastSync;

    debugPrint('Pull Phase: Checking contacts updated after ${lastSync.toIso8601String()}');
    // Pull Contacts
    final contactsResponse = await supabase
        .from('contacts')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSync.toIso8601String());

    final remoteContacts = List<Map<String, dynamic>>.from(contactsResponse);
    for (final remote in remoteContacts) {
      final id = remote['id'] as String;
      final remoteUpdatedAt = DateTime.parse(remote['updated_at'] as String);
      final isRemoteDeleted = remote['is_deleted'] as bool? ?? false;

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
                id: id,
                userId: userId,
                name: remote['name'] as String,
                phone: remote['phone'] as String?,
                createdAt: DateTime.parse(remote['created_at'] as String),
                updatedAt: remoteUpdatedAt,
                isDirty: false,
                isDeleted: false,
              ));
            }
            debugPrint('Conflict resolved (server won) for contact: $id');
          } else {
            debugPrint('Conflict resolved (local won) for contact: $id');
          }
        } else {
          if (isRemoteDeleted) {
            await db.hardDeleteContact(id);
          } else {
            await db.upsertContact(Contact(
              id: id,
              userId: userId,
              name: remote['name'] as String,
              phone: remote['phone'] as String?,
              createdAt: DateTime.parse(remote['created_at'] as String),
              updatedAt: remoteUpdatedAt,
              isDirty: false,
              isDeleted: false,
            ));
          }
        }
      } else if (!isRemoteDeleted) {
        await db.upsertContact(Contact(
          id: id,
          userId: userId,
          name: remote['name'] as String,
          phone: remote['phone'] as String?,
          createdAt: DateTime.parse(remote['created_at'] as String),
          updatedAt: remoteUpdatedAt,
          isDirty: false,
          isDeleted: false,
        ));
        debugPrint('Pulled new contact: $id');
      }
    }

    debugPrint('Pull Phase: Checking transactions updated after ${lastSync.toIso8601String()}');
    // Pull Transactions
    final txnsResponse = await supabase
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSync.toIso8601String());

    final remoteTxns = List<Map<String, dynamic>>.from(txnsResponse);
    for (final remote in remoteTxns) {
      final id = remote['id'] as String;
      final remoteUpdatedAt = DateTime.parse(remote['updated_at'] as String);
      final isRemoteDeleted = remote['is_deleted'] as bool? ?? false;

      if (remoteUpdatedAt.isAfter(newLastSync)) {
        newLastSync = remoteUpdatedAt;
      }

      final contactId = remote['contact_id'] as String;
      final localContact = await db.getContactById(contactId);
      if (localContact == null) {
        try {
          final cRes = await supabase.from('contacts').select().eq('id', contactId).maybeSingle();
          if (cRes != null) {
            await db.upsertContact(Contact(
              id: contactId,
              userId: userId,
              name: cRes['name'] as String,
              phone: cRes['phone'] as String?,
              createdAt: DateTime.parse(cRes['created_at'] as String),
              updatedAt: DateTime.parse(cRes['updated_at'] as String),
              isDirty: false,
              isDeleted: false,
            ));
          }
        } catch (e) {
          debugPrint('Failed to fetch contact $contactId for transaction: $e');
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
                id: id,
                contactId: contactId,
                userId: userId,
                amount: (remote['amount'] as num).toDouble(),
                type: remote['type'] as String,
                description: remote['description'] as String?,
                date: DateTime.parse(remote['date'] as String),
                createdAt: DateTime.parse(remote['created_at'] as String),
                updatedAt: remoteUpdatedAt,
                isDirty: false,
                isDeleted: false,
              ));
            }
            debugPrint('Conflict resolved (server won) for transaction: $id');
          } else {
            debugPrint('Conflict resolved (local won) for transaction: $id');
          }
        } else {
          if (isRemoteDeleted) {
            await db.hardDeleteTransaction(id);
          } else {
            await db.upsertTransaction(TransactionModel(
              id: id,
              contactId: contactId,
              userId: userId,
              amount: (remote['amount'] as num).toDouble(),
              type: remote['type'] as String,
              description: remote['description'] as String?,
              date: DateTime.parse(remote['date'] as String),
              createdAt: DateTime.parse(remote['created_at'] as String),
              updatedAt: remoteUpdatedAt,
              isDirty: false,
              isDeleted: false,
            ));
          }
        }
      } else if (!isRemoteDeleted) {
        await db.upsertTransaction(TransactionModel(
          id: id,
          contactId: contactId,
          userId: userId,
          amount: (remote['amount'] as num).toDouble(),
          type: remote['type'] as String,
          description: remote['description'] as String?,
          date: DateTime.parse(remote['date'] as String),
          createdAt: DateTime.parse(remote['created_at'] as String),
          updatedAt: remoteUpdatedAt,
          isDirty: false,
          isDeleted: false,
        ));
        debugPrint('Pulled new transaction: $id');
      }
    }

    debugPrint('Pull Phase: Checking expense categories updated after ${lastSync.toIso8601String()}');
    // Pull Expense Categories
    final expenseCategoriesResponse = await supabase
        .from('expense_categories')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSync.toIso8601String());

    final remoteExpenseCategories = List<Map<String, dynamic>>.from(expenseCategoriesResponse);
    for (final remote in remoteExpenseCategories) {
      final id = remote['id'] as String;
      final remoteUpdatedAt = DateTime.parse(remote['updated_at'] as String);
      final isRemoteDeleted = remote['is_deleted'] as bool? ?? false;

      if (remoteUpdatedAt.isAfter(newLastSync)) {
        newLastSync = remoteUpdatedAt;
      }

      final List<dynamic> subs = remote['sub_categories'] as List<dynamic>? ?? [];
      final subCategoriesJson = jsonEncode(subs.map((e) => e.toString()).toList());

      final local = await db.getExpenseCategoryById(id);
      if (local != null) {
        if (local.isDirty) {
          if (remoteUpdatedAt.isAfter(local.updatedAt)) {
            if (isRemoteDeleted) {
              await db.hardDeleteExpenseCategory(id);
            } else {
              await db.upsertExpenseCategory(ExpenseCategory(
                id: id,
                userId: userId,
                name: remote['name'] as String,
                icon: remote['icon'] as String,
                color: remote['color'] as String,
                subCategories: subCategoriesJson,
                createdAt: DateTime.parse(remote['created_at'] as String),
                updatedAt: remoteUpdatedAt,
                isDirty: false,
                isDeleted: false,
              ));
            }
            debugPrint('Conflict resolved (server won) for expense category: $id');
          } else {
            debugPrint('Conflict resolved (local won) for expense category: $id');
          }
        } else {
          if (isRemoteDeleted) {
            await db.hardDeleteExpenseCategory(id);
          } else {
            await db.upsertExpenseCategory(ExpenseCategory(
              id: id,
              userId: userId,
              name: remote['name'] as String,
              icon: remote['icon'] as String,
              color: remote['color'] as String,
              subCategories: subCategoriesJson,
              createdAt: DateTime.parse(remote['created_at'] as String),
              updatedAt: remoteUpdatedAt,
              isDirty: false,
              isDeleted: false,
            ));
          }
        }
      } else if (!isRemoteDeleted) {
        await db.upsertExpenseCategory(ExpenseCategory(
          id: id,
          userId: userId,
          name: remote['name'] as String,
          icon: remote['icon'] as String,
          color: remote['color'] as String,
          subCategories: subCategoriesJson,
          createdAt: DateTime.parse(remote['created_at'] as String),
          updatedAt: remoteUpdatedAt,
          isDirty: false,
          isDeleted: false,
        ));
        debugPrint('Pulled new expense category: $id');
      }
    }

    debugPrint('Pull Phase: Checking expenses updated after ${lastSync.toIso8601String()}');
    // Pull Expenses
    final expensesResponse = await supabase
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSync.toIso8601String());

    final remoteExpenses = List<Map<String, dynamic>>.from(expensesResponse);
    for (final remote in remoteExpenses) {
      final id = remote['id'] as String;
      final remoteUpdatedAt = DateTime.parse(remote['updated_at'] as String);
      final isRemoteDeleted = remote['is_deleted'] as bool? ?? false;

      if (remoteUpdatedAt.isAfter(newLastSync)) {
        newLastSync = remoteUpdatedAt;
      }

      final categoryId = remote['category_id'] as String;
      final localCategory = await db.getExpenseCategoryById(categoryId);
      if (localCategory == null) {
        try {
          final catRes = await supabase.from('expense_categories').select().eq('id', categoryId).maybeSingle();
          if (catRes != null) {
            final List<dynamic> subs = catRes['sub_categories'] as List<dynamic>? ?? [];
            await db.upsertExpenseCategory(ExpenseCategory(
              id: categoryId,
              userId: userId,
              name: catRes['name'] as String,
              icon: catRes['icon'] as String,
              color: catRes['color'] as String,
              subCategories: jsonEncode(subs.map((e) => e.toString()).toList()),
              createdAt: DateTime.parse(catRes['created_at'] as String),
              updatedAt: DateTime.parse(catRes['updated_at'] as String),
              isDirty: false,
              isDeleted: false,
            ));
          }
        } catch (e) {
          debugPrint('Failed to pull parent category for expense: $e');
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
                id: id,
                userId: userId,
                categoryId: categoryId,
                subCategory: remote['sub_category'] as String,
                amount: (remote['amount'] as num).toDouble(),
                remarks: remote['remarks'] as String?,
                date: DateTime.parse(remote['date'] as String),
                createdAt: DateTime.parse(remote['created_at'] as String),
                updatedAt: remoteUpdatedAt,
                isDirty: false,
                isDeleted: false,
              ));
            }
            debugPrint('Conflict resolved (server won) for expense: $id');
          } else {
            debugPrint('Conflict resolved (local won) for expense: $id');
          }
        } else {
          if (isRemoteDeleted) {
            await db.hardDeleteExpense(id);
          } else {
            await db.upsertExpense(Expense(
              id: id,
              userId: userId,
              categoryId: categoryId,
              subCategory: remote['sub_category'] as String,
              amount: (remote['amount'] as num).toDouble(),
              remarks: remote['remarks'] as String?,
              date: DateTime.parse(remote['date'] as String),
              createdAt: DateTime.parse(remote['created_at'] as String),
              updatedAt: remoteUpdatedAt,
              isDirty: false,
              isDeleted: false,
            ));
          }
        }
      } else if (!isRemoteDeleted) {
        await db.upsertExpense(Expense(
          id: id,
          userId: userId,
          categoryId: categoryId,
          subCategory: remote['sub_category'] as String,
          amount: (remote['amount'] as num).toDouble(),
          remarks: remote['remarks'] as String?,
          date: DateTime.parse(remote['date'] as String),
          createdAt: DateTime.parse(remote['created_at'] as String),
          updatedAt: remoteUpdatedAt,
          isDirty: false,
          isDeleted: false,
        ));
        debugPrint('Pulled new expense: $id');
      }
    }

    // Save updated sync timestamp
    if (newLastSync.isAfter(lastSync)) {
      await saveLastSyncTime(userId, newLastSync);
    }
  }
}

enum SyncStatus {
  synced,   // Data is matching remote server
  syncing,  // Upload/download process in progress
  offline,  // Offline mode, sync paused
  error     // Synced failed due to error
}
