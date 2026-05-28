import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Access the static singleton client instance
  static SupabaseClient get client => Supabase.instance.client;

  // Access current authenticated user
  static User? get currentUser => client.auth.currentUser;

  // Check if a session is currently active
  static bool get isAuthenticated => currentUser != null;

  // Sign in with email and password
  static Future<AuthResponse> signIn({required String email, required String password}) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  // Sign up a new user
  static Future<AuthResponse> signUp({required String email, required String password}) {
    return client.auth.signUp(email: email, password: password);
  }

  // Sign out the current user session
  static Future<void> signOut() {
    return client.auth.signOut();
  }
}
