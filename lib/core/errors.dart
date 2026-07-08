import 'package:pocketbase/pocketbase.dart';

class ErrorMessages {
  static String getAuthError(Object? error) {
    if (error == null) {
      return 'Something went wrong. Please try again.';
    }
    if (error is ClientException) {
      final response = error.response;
      final msg = response['message'] is String ? response['message'] as String : null;

      if (msg != null) {
        final lower = msg.toLowerCase();
        if (lower.contains('invalid') || lower.contains('failed to authenticate')) {
          return 'Invalid email or password. Please try again.';
        }
        if (lower.contains('email not verified')) {
          return 'Please verify your email address before logging in.';
        }
        if (lower.contains('rate limit') || lower.contains('too many requests')) {
          return 'Too many attempts. Please try again later.';
        }
      }

      switch (error.statusCode) {
        case 401:
          return 'Invalid email or password. Please try again.';
        case 403:
          return 'Access denied. Please verify your account.';
        case 404:
          return 'Account not found. Please sign up.';
        case 429:
          return 'Too many attempts. Please try again later.';
        case 500:
          return 'Server error. Please try again later.';
      }
      return 'Authentication failed. Please try again.';
    }

    if (error is String) {
      if (error.contains('Google sign-in cancelled')) {
        return 'Google sign-in cancelled';
      }
    }

    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('socketexception') ||
        errorStr.contains('handshakeexception') ||
        errorStr.contains('timeoutexception')) {
      return 'No internet connection. Please check your network.';
    }

    return 'Something went wrong. Please try again.';
  }

  static String get networkError => 'No internet connection. Please check your network.';
  static String get serverError => 'Server error. Please try again later.';
  static String get generalError => 'Something went wrong. Please try again.';

  // Inline loading errors (for Center child: Text('Error: $e'))
  static String get expensesError => 'Could not load expenses. Pull down to refresh.';
  static String get categoriesError => 'Could not load categories. Pull down to refresh.';
  static String get contactsError => 'Could not load contacts. Pull down to refresh.';
  static String get transactionsError => 'Could not load transactions. Pull down to refresh.';
}
