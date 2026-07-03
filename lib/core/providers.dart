import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:drift/drift.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'database/local_db.dart';
import 'sync/sync_engine.dart';
import 'pocketbase/pocketbase_client.dart';

const _oldIdPrefix = 'c0000000-';

Future<void> initializeExpenseSystem(AppDatabase db, String currentUserId) async {
  if (currentUserId == 'guest') return;

  final existingCategories = await (db.select(db.expenseCategories)..where((t) => t.userId.equals(currentUserId))).get();

  // Migrate old-format IDs (c0000000-... or guest-...) to new userId-prefixed format
  final oldFormats = existingCategories.where((c) => c.id.startsWith(_oldIdPrefix) || c.id.startsWith('guest-')).toList();
  if (oldFormats.isNotEmpty) {
    for (final cat in oldFormats) {
      await db.hardDeleteExpenseCategory(cat.id);
    }
  }

  // Re-check: re-read after migration deletions
  final remaining = await (db.select(db.expenseCategories)..where((t) => t.userId.equals(currentUserId))).get();
  if (remaining.isEmpty) {
    final defaultCategories = [
      {"id": "food", "name": "Food & Dining", "icon": "restaurant_rounded", "color": "#FF9F43", "sub": ["Groceries", "Snacks", "Restaurants", "Chai & Coffee"]},
      {"id": "shopping", "name": "Shopping", "icon": "shopping_bag_rounded", "color": "#FF5252", "sub": ["Clothes", "Electronics", "Gifts", "Personal Care"]},
      {"id": "transport", "name": "Transport", "icon": "directions_car_rounded", "color": "#536DFE", "sub": ["Fuel", "Cab & Auto", "Public Transport", "Maintenance"]},
      {"id": "bills", "name": "Bills & Rent", "icon": "receipt_long_rounded", "color": "#9C27B0", "sub": ["Rent", "Electricity", "Internet & Mobile", "DTH / Gas"]},
      {"id": "entertainment", "name": "Entertainment", "icon": "movie_filter_rounded", "color": "#E040FB", "sub": ["Movies", "OTT Subscriptions", "Gaming", "Outing"]},
      {"id": "health", "name": "Health", "icon": "medical_services_rounded", "color": "#00E676", "sub": ["Medicines", "Consultation", "Lab Tests", "Insurance"]},
      {"id": "others", "name": "Others", "icon": "category_rounded", "color": "#90A4AE", "sub": ["General", "Cash Withdrawal", "Misc Expenses"]}
    ];

    for (final cat in defaultCategories) {
      final String staticId = '$currentUserId-${cat['id']}';

      await db.upsertExpenseCategory(ExpenseCategory(
        id: staticId,
        userId: currentUserId,
        name: cat['name'] as String,
        icon: cat['icon'] as String,
        color: cat['color'] as String,
        subCategories: jsonEncode(cat['sub']),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDirty: currentUserId != 'guest',
        isDeleted: false,
      ));
    }
  }
}

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(dbProvider);
  return SyncEngine(db);
});

final authStateProvider = StreamProvider<RecordModel?>((ref) async* {
  final pb = PocketBaseService.client;
  yield pb.authStore.record;
  await for (final event in pb.authStore.onChange) {
    yield event.record;
  }
});

final userIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.id ?? 'guest';

  final db = ref.read(dbProvider);
  initializeExpenseSystem(db, userId);

  return userId;
});

class SyncStatusNotifier extends Notifier<SyncStatus> {
  SyncEngine? _engine;

  @override
  SyncStatus build() {
    _engine = ref.watch(syncEngineProvider);
    _engine!.statusNotifier.addListener(_onStatusChange);
    ref.onDispose(() => _engine!.statusNotifier.removeListener(_onStatusChange));
    return _engine!.statusNotifier.value;
  }

  void _onStatusChange() {
    state = _engine!.statusNotifier.value;
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);

class AuthNotifier extends AsyncNotifier<RecordModel?> {
  @override
  FutureOr<RecordModel?> build() {
    return PocketBaseService.currentUser;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final authRes = await PocketBaseService.signIn(email: email, password: password);
      final newUserId = authRes.record.id;
      if (newUserId.isNotEmpty) {
        await _migrateGuestData(newUserId);
      }
      state = AsyncValue.data(authRes.record);
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signup(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final record = await PocketBaseService.signUp(email: email, password: password);
      final newUserId = record.id;
      if (newUserId.isNotEmpty) {
        await _migrateGuestData(newUserId);
      }
      state = AsyncValue.data(record);
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _migrateGuestData(String newUserId) async {
    final db = ref.read(dbProvider);
    await db.transaction(() async {
      await (db.update(db.contacts)..where((t) => t.userId.equals('guest'))).write(
        ContactsCompanion(
          userId: Value(newUserId),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (db.update(db.transactions)..where((t) => t.userId.equals('guest'))).write(
        TransactionsCompanion(
          userId: Value(newUserId),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      // Rewrite guest-prefixed category IDs (guest-food → newUserId-food)
      final guestCats = await (db.select(db.expenseCategories)..where((t) => t.userId.equals('guest'))).get();
      for (final cat in guestCats) {
        final newId = cat.id.startsWith('guest-')
            ? cat.id.replaceFirst('guest-', '$newUserId-')
            : '$newUserId-${cat.id}';
        await db.upsertExpenseCategory(cat.copyWith(
          id: newId,
          userId: newUserId,
          isDirty: true,
          updatedAt: DateTime.now(),
        ));
        // Delete old record by old id
        await db.hardDeleteExpenseCategory(cat.id);
      }
      await (db.update(db.expenses)..where((t) => t.userId.equals('guest'))).write(
        ExpensesCompanion(
          userId: Value(newUserId),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      await PocketBaseService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      state = AsyncValue.error(e, stack);
    }
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, RecordModel?>(AuthNotifier.new);

final contactsStreamProvider = StreamProvider.family<List<Contact>, String>((ref, userId) {
  final db = ref.watch(dbProvider);
  return db.watchContacts(userId);
});

final transactionsStreamProvider = StreamProvider.family<List<TransactionModel>, String>((ref, contactId) {
  final db = ref.watch(dbProvider);
  return db.watchTransactionsForContact(contactId);
});

final allTransactionsStreamProvider = StreamProvider.family<List<TransactionModel>, String>((ref, userId) {
  final db = ref.watch(dbProvider);
  return db.watchAllTransactions(userId);
});

final expenseCategoriesStreamProvider = StreamProvider.family<List<ExpenseCategory>, String>((ref, userId) {
  final db = ref.watch(dbProvider);
  return db.watchExpenseCategories(userId);
});

final expensesStreamProvider = StreamProvider.family<List<Expense>, String>((ref, userId) {
  final db = ref.watch(dbProvider);
  return db.watchExpenses(userId);
});
