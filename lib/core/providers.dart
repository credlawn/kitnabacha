import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import 'database/local_db.dart';
import 'sync/sync_engine.dart';
import 'supabase/supabase_client.dart';

String _getCategoryDigit(String catId) {
  switch (catId) {
    case 'food': return '1';
    case 'shopping': return '2';
    case 'transport': return '3';
    case 'bills': return '4';
    case 'entertainment': return '5';
    case 'health': return '6';
    default: return '7';
  }
}

Future<void> initializeExpenseSystem(AppDatabase db, String currentUserId) async {
  // Check if any expense categories exist for this user
  final existingCategories = await (db.select(db.expenseCategories)..where((t) => t.userId.equals(currentUserId))).get();
  if (existingCategories.isEmpty) {
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
      // Generate a static UUID namespace based on category ID to prevent duplicate categories on sync
      final String staticId = 'c0000000-0000-0000-0000-00000000000${_getCategoryDigit(cat['id'] as String)}';

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

// Provide Drift database instance
final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Provide Background Sync Engine instance
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(dbProvider);
  return SyncEngine(db);
});

// Watch current authentication changes
final authStateProvider = StreamProvider<User?>((ref) {
  return SupabaseService.client.auth.onAuthStateChange.map((event) => event.session?.user);
});

// Dynamic User ID Provider (defaults to 'guest' if unauthenticated)
final userIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.value?.id ?? 'guest';
  
  final db = ref.read(dbProvider);
  initializeExpenseSystem(db, userId);
  
  return userId;
});

// Watch sync engine status using StateNotifier
class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  final SyncEngine _engine;

  SyncStatusNotifier(this._engine) : super(_engine.statusNotifier.value) {
    _engine.statusNotifier.addListener(_listener);
  }

  void _listener() {
    state = _engine.statusNotifier.value;
  }

  @override
  void dispose() {
    _engine.statusNotifier.removeListener(_listener);
    super.dispose();
  }
}

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return SyncStatusNotifier(engine);
});

// StateNotifier to handle signup, login, logout flows with visual loading states
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AsyncValue.data(null)) {
    state = AsyncValue.data(SupabaseService.currentUser);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await SupabaseService.signIn(email: email, password: password);
      final newUserId = res.user?.id;
      if (newUserId != null) {
        await _migrateGuestData(newUserId);
      }
      state = AsyncValue.data(res.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> signup(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await SupabaseService.signUp(email: email, password: password);
      final newUserId = res.user?.id;
      if (newUserId != null) {
        await _migrateGuestData(newUserId);
      }
      state = AsyncValue.data(res.user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _migrateGuestData(String newUserId) async {
    final db = ref.read(dbProvider);
    await db.transaction(() async {
      // 1. Update contacts from 'guest' to the new user ID
      await (db.update(db.contacts)..where((t) => t.userId.equals('guest'))).write(
        ContactsCompanion(
          userId: Value(newUserId),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      // 2. Update transactions from 'guest' to the new user ID
      await (db.update(db.transactions)..where((t) => t.userId.equals('guest'))).write(
        TransactionsCompanion(
          userId: Value(newUserId),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      // 3. Update expense categories from 'guest' to the new user ID
      await (db.update(db.expenseCategories)..where((t) => t.userId.equals('guest'))).write(
        ExpenseCategoriesCompanion(
          userId: Value(newUserId),
          isDirty: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      // 4. Update expenses from 'guest' to the new user ID
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
      await SupabaseService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref);
});

// Watch contacts stream provider
final contactsStreamProvider = StreamProvider.family<List<Contact>, String>((ref, userId) {
  final db = ref.watch(dbProvider);
  return db.watchContacts(userId);
});

// Watch transactions stream provider for a contact
final transactionsStreamProvider = StreamProvider.family<List<TransactionModel>, String>((ref, contactId) {
  final db = ref.watch(dbProvider);
  return db.watchTransactionsForContact(contactId);
});

// Watch all transactions stream provider for dashboard calculations
final allTransactionsStreamProvider = StreamProvider.family<List<TransactionModel>, String>((ref, userId) {
  final db = ref.watch(dbProvider);
  return db.watchAllTransactions(userId);
});

// Watch expense categories stream provider
final expenseCategoriesStreamProvider = StreamProvider.family<List<ExpenseCategory>, String>((ref, userId) {
  final db = ref.watch(dbProvider);
  return db.watchExpenseCategories(userId);
});

// Watch expenses stream provider
final expensesStreamProvider = StreamProvider.family<List<Expense>, String>((ref, userId) {
  final db = ref.watch(dbProvider);
  return db.watchExpenses(userId);
});
