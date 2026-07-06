import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgeo/core/providers.dart';
import 'package:ledgeo/core/sync/sync_engine.dart';
import 'package:ledgeo/main.dart';

class SyncStatusMock extends SyncStatusNotifier {
  @override
  SyncStatus build() => SyncStatus.synced;
}

void main() {
  testWidgets('MyApp renders dashboard successfully for guest user', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userIdProvider.overrideWithValue('guest'),
          contactsStreamProvider('guest').overrideWith((ref) => const Stream.empty()),
          allTransactionsStreamProvider('guest').overrideWith((ref) => const Stream.empty()),
          syncStatusProvider.overrideWith(() => SyncStatusMock()),
        ],
        child: const MyApp(),
      ),
    );

    // Complete onboarding by tapping Skip (fastest path to dashboard)
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dashboard renders
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Ledgeo'), findsOneWidget);
  });
}
