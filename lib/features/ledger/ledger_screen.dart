import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/local_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/add_transaction_sheet.dart';

class LedgerScreen extends ConsumerWidget {
  final Contact contact;
  final String userId;

  const LedgerScreen({
    super.key,
    required this.contact,
    required this.userId,
  });

  // Calculate current contact net balance from transactions list
  double _calculateContactBalance(List<TransactionModel> txns) {
    double balance = 0;
    for (final txn in txns) {
      if (txn.type == 'give' || txn.type == 'pay') {
        balance += txn.amount;
      } else {
        balance -= txn.amount;
      }
    }
    return balance;
  }

  // Delete Contact confirmation dialog
  void _confirmDeleteContact(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text('Delete Contact?'),
          content: Text('Are you sure you want to delete ${contact.name}? All transaction history with them will be deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                final db = ref.read(dbProvider);
                // Perform local soft-delete
                await db.softDeleteContact(contact.id);
                // Trigger sync in background
                ref.read(syncEngineProvider).triggerSync();
                
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Pop ledger screen back to dashboard
                }
              },
              child: const Text('Delete', style: TextStyle(color: AppTheme.debitRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Long-press transaction deletion confirmation
  void _confirmDeleteTransaction(BuildContext context, WidgetRef ref, TransactionModel txn) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: const Text('Delete Entry?'),
          content: Text('Delete this transaction of ₹${txn.amount.toStringAsFixed(2)}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                final db = ref.read(dbProvider);
                await db.softDeleteTransaction(txn.id);
                
                // Update contact updatedAt timestamp
                await db.upsertContact(contact.copyWith(
                  updatedAt: DateTime.now(),
                  isDirty: true,
                ));

                ref.read(syncEngineProvider).triggerSync();

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Delete', style: TextStyle(color: AppTheme.debitRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Copy structured payment reminder text to clipboard
  void _copyPaymentReminder(BuildContext context, double balance) {
    if (balance == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance is settled. No reminder needed.')),
      );
      return;
    }

    final String formattedAmt = '₹${balance.abs().toStringAsFixed(2)}';
    String reminderText;

    if (balance > 0) {
      // They owe us money
      reminderText = 
          'Hello ${contact.name},\n'
          'This is a friendly reminder that your outstanding balance in our ledger is $formattedAmt. '
          'Please make the payment as soon as possible. Thank you!\n\n'
          'नमस्ते ${contact.name},\n'
          'यह एक विनम्र अनुस्मारक है कि हमारे हिसाब-किताब का बकाया $formattedAmt है। '
          'कृपया जल्द ही भुगतान करें। धन्यवाद!';
    } else {
      // We owe them money
      reminderText = 
          'Hello ${contact.name},\n'
          'I wanted to remind you that I owe you $formattedAmt in our ledger. '
          'I am processing the payment and will clear it soon. Thank you!\n\n'
          'नमस्ते ${contact.name},\n'
          'मैं आपको याद दिलाना चाहता था कि मुझे आपको $formattedAmt देने हैं। '
          'मैं जल्द ही इसका भुगतान कर दूंगा। धन्यवाद!';
    }

    Clipboard.setData(ClipboardData(text: reminderText)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder for ${contact.name} copied to clipboard!'),
          backgroundColor: AppTheme.primary,
        ),
      );
    });
  }

  // Open add transaction sheet
  void _openAddTransactionSheet(BuildContext context, bool isOutflow, double currentBalance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        contact: contact,
        userId: userId,
        isOutflow: isOutflow,
        currentBalance: currentBalance,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsState = ref.watch(transactionsStreamProvider(contact.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contact.name),
            if (contact.phone != null)
              Text(
                contact.phone!,
                style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.debitRed),
            tooltip: 'Delete Contact',
            onPressed: () => _confirmDeleteContact(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: txnsState.when(
        data: (txns) {
          final balance = _calculateContactBalance(txns);

          return Column(
            children: [
              // 1. Contact Balance Card Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: AppTheme.glassmorphicBox(
                    gradient: balance >= 0
                        ? (balance > 0 ? AppTheme.greenCardGradient : AppTheme.premiumCardGradient)
                        : AppTheme.redCardGradient,
                  ),
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              balance > 0
                                  ? 'THEY OWE YOU (LENA HAI)'
                                  : balance < 0
                                      ? 'YOU OWE THEM (DENA HAI)'
                                      : 'SETTLED (HISAB BARABAR)',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${balance.abs().toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (balance != 0)
                        ElevatedButton.icon(
                          onPressed: () => _copyPaymentReminder(context, balance),
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Reminder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white12,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 2. Chat-feed style transaction ledger
              Expanded(
                child: txns.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              size: 48,
                              color: AppTheme.secondaryText.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Koi transaction nahi mila.\nNiche diye buttons se hisab shuru karein!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.secondaryText),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90),
                        reverse: false, // Normal chronological listing or reverse? Usually reverse is best so new entries appear at the bottom!
                        // Let's implement lists sorted by date, displaying from oldest at top to newest at bottom so it scrolls like a conversation chat feed.
                        itemCount: txns.length,
                        itemBuilder: (context, index) {
                          // To scroll like chat (oldest first, newest bottom), we reverse index logic
                          final txn = txns[txns.length - 1 - index];
                          final isOutflow = txn.type == 'give' || txn.type == 'pay';
                          final dateStr = DateFormat('dd MMM yyyy').format(txn.date);
                          final syncIcon = txn.isDirty
                              ? const Icon(Icons.access_time_rounded, size: 11, color: AppTheme.warningOrange)
                              : const Icon(Icons.done_all_rounded, size: 11, color: AppTheme.primaryLight);

                          // Left aligned is OUTFLOW (I gave / Red card)
                          // Right aligned is INFLOW (I got / Green card)
                          return Align(
                            alignment: isOutflow ? Alignment.centerLeft : Alignment.centerRight,
                            child: InkWell(
                              onLongPress: () => _confirmDeleteTransaction(context, ref, txn),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: AppTheme.glassmorphicBox(
                                  color: isOutflow
                                      ? AppTheme.debitRedBg.withOpacity(0.2)
                                      : AppTheme.creditGreenBg.withOpacity(0.2),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      isOutflow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '₹${txn.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: isOutflow ? AppTheme.debitRed : AppTheme.creditGreen,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Label matching action
                                        Text(
                                          txn.type == 'give'
                                              ? '(Gave)'
                                              : txn.type == 'pay'
                                                  ? '(Paid)'
                                                  : txn.type == 'receive'
                                                      ? '(Got)'
                                                      : '(Took)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isOutflow
                                                ? AppTheme.debitRed.withOpacity(0.6)
                                                : AppTheme.creditGreen.withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (txn.description != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        txn.description!,
                                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: const TextStyle(fontSize: 9, color: AppTheme.secondaryText),
                                        ),
                                        const SizedBox(width: 4),
                                        syncIcon,
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      // 3. Bottom persistent dual buttons: "Maine Diye" & "Maine Liye"
      bottomSheet: Consumer(
        builder: (context, ref, child) {
          final txnsData = ref.watch(transactionsStreamProvider(contact.id));
          final double balance = txnsData.when(
            data: (txns) => _calculateContactBalance(txns),
            loading: () => 0.0,
            error: (_, __) => 0.0,
          );

          return Container(
            color: AppTheme.darkBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openAddTransactionSheet(context, true, balance),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.debitRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_circle_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Maine Diye (-)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _openAddTransactionSheet(context, false, balance),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.creditGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Maine Liye (+)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
