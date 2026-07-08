import 'dart:io';
import 'package:pocketbase/pocketbase.dart';
import 'package:path_provider/path_provider.dart';
import 'pocketbase_config.dart';

class PocketBaseService {
  static late final PocketBase _pb;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/pb_auth.json');

    String? initial;
    if (await file.exists()) {
      initial = await file.readAsString();
    }

    _pb = PocketBase(
      PocketBaseConfig.url,
      authStore: AsyncAuthStore(
        save: (data) async {
          await file.writeAsString(data);
        },
        initial: initial,
        clear: () async {
          if (await file.exists()) {
            await file.delete();
          }
        },
      ),
    );
  }

  static PocketBase get client {
    if (!_initialized) {
      throw StateError('PocketBaseService.init() must be called first');
    }
    return _pb;
  }

  static RecordModel? get currentUser => client.authStore.record;

  static bool get isAuthenticated => client.authStore.isValid;

  static Future<RecordAuth> signIn({required String email, required String password}) {
    return client.collection('users').authWithPassword(email, password);
  }

  static Future<RecordModel> signUp({required String email, required String password}) {
    return client.collection('users').create(body: {
      'email': email,
      'password': password,
      'passwordConfirm': password,
    });
  }

  static Future<RecordAuth> signInWithGoogle(String idToken) async {
    final data = await client.send<Map<String, dynamic>>(
      '/api/auth/google',
      method: 'POST',
      body: {'idToken': idToken},
    );

    final token = data['token'] as String;
    final record = RecordModel.fromJson(data['record'] as Map<String, dynamic>);

    client.authStore.save(token, record);

    return RecordAuth(token: token, record: record);
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    return client.send<Map<String, dynamic>>(
      '/api/account/delete',
      method: 'POST',
    );
  }

  static Future<Map<String, dynamic>> getAccountStatus() async {
    return client.send<Map<String, dynamic>>(
      '/api/account/status',
      method: 'POST',
    );
  }

  static Future<Map<String, dynamic>> restoreAccount() async {
    return client.send<Map<String, dynamic>>(
      '/api/account/restore',
      method: 'POST',
    );
  }

  static Future<void> signOut() async {
    client.authStore.clear();
  }
}
