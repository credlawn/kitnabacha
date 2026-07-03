import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/local_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/add_transaction_sheet.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  final Contact contact;
  final String userId;

  const LedgerScreen({
    super.key,
    required this.contact,
    required this.userId,
  });

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  DateTime? _selectedMonth;

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
  Future<void> _confirmDeleteContact(BuildContext context) async {
    final txns = await ref.read(dbProvider).getActiveTransactionsForContact(widget.contact.id);
    if (txns > 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete — $txns transaction(s) exist. Delete them first.'),
          backgroundColor: AppTheme.debitRed,
        ),
      );
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('Delete Contact?'),
          content: Text('Are you sure you want to delete "${widget.contact.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
            ),
            TextButton(
              onPressed: () async {
                final db = ref.read(dbProvider);
                await db.softDeleteContact(widget.contact.id);
                ref.read(syncEngineProvider).triggerSync();
                
                if (context.mounted) {
                  Navigator.pop(context);
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

  // Reusable delete confirmation dialog returning true/false
  Future<bool?> _confirmDeleteTransactionDialog(BuildContext context, TransactionModel txn) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('Delete Entry?'),
          content: Text('Delete this transaction of ${AppTheme.formatAmount(txn.amount)}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppTheme.debitRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Handle transaction soft-delete logic
  Future<void> _deleteTransaction(WidgetRef ref, TransactionModel txn) async {
    final db = ref.read(dbProvider);
    await db.softDeleteTransaction(txn.id);
    
    // Update contact updatedAt timestamp
    await db.upsertContact(widget.contact.copyWith(
      updatedAt: DateTime.now(),
      isDirty: true,
    ));

    ref.read(syncEngineProvider).triggerSync();
  }

  // Long-press transaction deletion confirmation
  void _confirmDeleteTransaction(BuildContext context, WidgetRef ref, TransactionModel txn) async {
    final confirmed = await _confirmDeleteTransactionDialog(context, txn);
    if (confirmed == true) {
      await _deleteTransaction(ref, txn);
    }
  }

  // Copy structured payment reminder text to clipboard
  void _copyPaymentReminder(BuildContext context, double balance) {
    if (balance == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance is settled. No reminder needed.')),
      );
      return;
    }

    final String formattedAmt = AppTheme.formatAmount(balance.abs());
    String reminderText;

    if (balance > 0) {
      // They owe us money
      reminderText = 
          'Hello ${widget.contact.name},\n'
          'This is a friendly reminder that your outstanding balance in our ledger is $formattedAmt. '
          'Please make the payment as soon as possible. Thank you!\n\n'
          'नमस्ते ${widget.contact.name},\n'
          'यह एक विनम्र अनुस्मारक है कि हमारे हिसाब-किताब का बकाया $formattedAmt है। '
          'कृपया जल्द ही भुगतान करें। धन्यवाद!';
    } else {
      // We owe them money
      reminderText = 
          'Hello ${widget.contact.name},\n'
          'I wanted to remind you that I owe you $formattedAmt in our ledger. '
          'I am processing the payment and will clear it soon. Thank you!\n\n'
          'नमस्ते ${widget.contact.name},\n'
          'मैं आपको याद दिलाना चाहता था कि मुझे आपको $formattedAmt देने हैं। '
          'मैं जल्द ही इसका भुगतान कर दूंगा। धन्यवाद!';
    }

    Clipboard.setData(ClipboardData(text: reminderText)).then((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder for ${widget.contact.name} copied to clipboard!'),
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
        contact: widget.contact,
        userId: widget.userId,
        isOutflow: isOutflow,
        currentBalance: currentBalance,
      ),
    );
  }

  // Open edit transaction sheet
  void _openEditTransactionSheet(BuildContext context, TransactionModel txn, double currentBalance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        contact: widget.contact,
        userId: widget.userId,
        isOutflow: txn.type == 'give' || txn.type == 'pay',
        currentBalance: currentBalance,
        transactionToEdit: txn,
      ),
    );
  }

  // Show Bottom Sheet to Pick Month Filter
  void _showMonthPicker(BuildContext context, List<DateTime> uniqueMonths) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter by Month',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Option: All Time
                      ListTile(
                        leading: const Icon(Icons.all_inclusive_rounded, color: AppTheme.primary),
                        title: const Text('All Time (Lifetime)'),
                        trailing: _selectedMonth == null
                            ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary)
                            : null,
                        onTap: () {
                          setState(() => _selectedMonth = null);
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(),
                      // Options for each month
                      ...uniqueMonths.map((month) {
                        final label = DateFormat('MMMM yyyy').format(month);
                        final formattedFilter = DateFormat('MMM-yy').format(month);
                        final isSelected = _selectedMonth != null &&
                            _selectedMonth!.year == month.year &&
                            _selectedMonth!.month == month.month;

                        return ListTile(
                          leading: const Icon(Icons.calendar_month_rounded),
                          title: Text(label),
                          subtitle: Text(formattedFilter),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary)
                              : null,
                          onTap: () {
                            setState(() => _selectedMonth = month);
                            Navigator.pop(context);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final txnsState = ref.watch(transactionsStreamProvider(widget.contact.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.contact.name),
            if (widget.contact.phone != null)
              Text(
                widget.contact.phone!,
                style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
              ),
          ],
        ),
        actions: [
          // Dynamic Month Filter Action
          txnsState.maybeWhen(
            data: (txns) {
              final uniqueMonths = txns
                  .map((t) => DateTime(t.date.year, t.date.month))
                  .toSet()
                  .toList();
              uniqueMonths.sort((a, b) => b.compareTo(a));

              final filterLabel = _selectedMonth == null
                  ? 'All'
                  : DateFormat('MMM-yy').format(_selectedMonth!);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: TextButton.icon(
                  onPressed: () => _showMonthPicker(context, uniqueMonths),
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkBorder
                        : AppTheme.lightBorder,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 14, color: AppTheme.primary),
                  label: Text(
                    filterLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.debitRed),
            tooltip: 'Delete Contact',
            onPressed: () => _confirmDeleteContact(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: txnsState.when(
        data: (txns) {
          final lifetimeBalance = _calculateContactBalance(txns);

          // Get dynamic unique months for list filtering
          final uniqueMonths = txns
              .map((t) => DateTime(t.date.year, t.date.month))
              .toSet()
              .toList();
          uniqueMonths.sort((a, b) => b.compareTo(a));

          // Filter transactions if a month is selected
          final filteredTxns = _selectedMonth == null
              ? txns
              : txns.where((t) {
                  return t.date.year == _selectedMonth!.year &&
                      t.date.month == _selectedMonth!.month;
                }).toList();

          final displayBalance = _calculateContactBalance(filteredTxns);

          return Column(
            children: [
              // 1. Contact Balance Card Header (Shows filtered outstanding balance)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: AppTheme.glassmorphicBox(
                    context: context,
                    gradient: displayBalance >= 0
                        ? (displayBalance > 0
                            ? AppTheme.greenCardGradient
                            : (Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.premiumCardGradient
                                : AppTheme.premiumCardLightGradient))
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
                              displayBalance > 0
                                  ? 'THEY OWE YOU (LENA HAI)'
                                  : displayBalance < 0
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
                              AppTheme.formatAmount(displayBalance.abs()),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (displayBalance != 0)
                        ElevatedButton.icon(
                          onPressed: () => _copyPaymentReminder(context, lifetimeBalance),
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

              // Filter sub-header info text if filtered
              if (_selectedMonth != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transactions in ${DateFormat('MMMM yyyy').format(_selectedMonth!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _selectedMonth = null),
                        child: const Text(
                          'Clear Filter',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Chat-feed style transaction ledger
              Expanded(
                child: filteredTxns.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              size: 48,
                              color: AppTheme.secondaryText.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedMonth != null
                                  ? 'Is mahine me koi transaction nahi mila.'
                                  : 'Koi transaction nahi mila.\nNiche diye buttons se hisab shuru karein!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.secondaryText),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90),
                        reverse: false,
                        itemCount: filteredTxns.length,
                        itemBuilder: (context, index) {
                          // Display in descending order (newest first, oldest last)
                          final txn = filteredTxns[index];
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
                              onTap: () => _openEditTransactionSheet(context, txn, lifetimeBalance),
                              onLongPress: () => _confirmDeleteTransaction(context, ref, txn),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: AppTheme.glassmorphicBox(
                                  context: context,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Column(
                                  crossAxisAlignment:
                                      isOutflow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AppTheme.formatAmount(txn.amount),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: isOutflow ? AppTheme.debitRed : AppTheme.creditGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (txn.description != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        txn.description!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.white.withValues(alpha: 0.9)
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? AppTheme.secondaryText
                                                : AppTheme.lightTextSecondary,
                                          ),
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
          final txnsData = ref.watch(transactionsStreamProvider(widget.contact.id));
          final double balance = txnsData.when(
            data: (txns) => _calculateContactBalance(txns),
            loading: () => 0.0,
            error: (_, _) => 0.0,
          );

          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
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
