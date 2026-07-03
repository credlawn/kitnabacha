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

  static Future<void> signOut() async {
    client.authStore.clear();
  }
}
