import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await GoogleSignIn.instance.initialize(
      serverClientId:
          const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
    );
  }

  static Future<String?> getIdToken() async {
    try {
      await init();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: ['email', 'profile'],
      );
      return account.authentication.idToken;
    } catch (e) {
      return null;
    }
  }

  static Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
  }
}
