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
      if (contact.isDeleted) {
        // Delete from server first, then local SQLite hard-delete
        await supabase.from('contacts').delete().eq('id', contact.id);
        await db.hardDeleteContact(contact.id);
        debugPrint('Pushed deleted contact: ${contact.id}');
      } else {
        // Upsert to server
        await supabase.from('contacts').upsert({
          'id': contact.id,
          'user_id': contact.userId,
          'name': contact.name,
          'phone': contact.phone,
          'created_at': contact.createdAt.toIso8601String(),
          'updated_at': contact.updatedAt.toIso8601String(),
          'is_deleted': false,
        });
        // Clear local dirty flag
        await db.upsertContact(contact.copyWith(isDirty: false));
        debugPrint('Pushed upserted contact: ${contact.name}');
      }
    }

    debugPrint('Push Phase: Syncing transactions...');
    // Push Transactions
    final dirtyTxns = await db.getDirtyTransactions(userId);
    for (final txn in dirtyTxns) {
      if (txn.isDeleted) {
        // Delete from server first, then local SQLite hard-delete
        await supabase.from('transactions').delete().eq('id', txn.id);
        await db.hardDeleteTransaction(txn.id);
        debugPrint('Pushed deleted transaction: ${txn.id}');
      } else {
        // Upsert to server
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
        // Clear local dirty flag
        await db.upsertTransaction(txn.copyWith(isDirty: false));
        debugPrint('Pushed upserted transaction: ${txn.id}');
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
        // Conflict check
        if (local.isDirty) {
          // Last Write Wins (LWW) conflict resolution
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
          // Local is not dirty, simply update/delete based on server
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
        // Does not exist locally, download it
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

      // Check if contact exists locally. If not, we might fail foreign key constraint.
      // So fetch/upsert the contact metadata first if needed.
      final contactId = remote['contact_id'] as String;
      final localContact = await db.getContactById(contactId);
      if (localContact == null) {
        // Fetch contact from server
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
          continue; // Skip transaction if parent contact cannot be added
        }
      }

      // Check transaction local model
      // Note: Drift class name is TransactionModel (mapping table Transactions)
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
