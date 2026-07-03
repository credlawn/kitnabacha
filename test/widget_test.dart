import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitnabacha/core/providers.dart';
import 'package:kitnabacha/core/sync/sync_engine.dart';
import 'package:kitnabacha/main.dart';

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

    // Let the streams and frames resolve
    await tester.pumpAndSettle();

    // Verify that MaterialApp and title are rendered
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('कितना बचा ?'), findsOneWidget);
    expect(find.text('Add Contact'), findsOneWidget);
  });
}
