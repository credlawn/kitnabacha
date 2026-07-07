import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers.dart';
import 'core/settings_provider.dart';
import 'core/pocketbase/pocketbase_client.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://575908ba7d8033c116851e541cadb4df@o4511670483550208.ingest.de.sentry.io/4511670489120848';
      options.tracesSampleRate = 1.0;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
      await PocketBaseService.init();
      final prefs = await SharedPreferences.getInstance();
      cachePrefs(prefs);

      runApp(
        const ProviderScope(
          child: MyApp(),
        ),
      );
    },
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _showOnboarding = true;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userIdProvider);
    final authState = ref.watch(authStateProvider);

    authState.whenData((user) {
      if (user != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(syncEngineProvider).triggerSync();
        });
      }
    });

    return MaterialApp(
      title: 'Ledgeo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: _showOnboarding
          ? OnboardingScreen(onComplete: () => setState(() => _showOnboarding = false))
          : authState.when(
              data: (user) => DashboardScreen(userId: userId),
              loading: () => const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
              error: (err, stack) => Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, color: AppTheme.debitRed, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Configuration Required',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please check your PocketBase server is running and the URL is correct.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(authStateProvider),
                          icon: Icon(Icons.refresh_rounded),
                          label: Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
