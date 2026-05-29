import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import 'database/local_db.dart';
import 'sync/sync_engine.dart';
import 'supabase/supabase_client.dart';

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
  return authState.value?.id ?? 'guest';
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

// ValueProvider is no longer needed.
