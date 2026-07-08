import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/local_db.dart';
import '../../core/providers.dart';
import '../../core/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/delete_confirm_dialog.dart';
import '../contacts/add_contact_screen.dart';
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

  Future<void> _confirmDeleteContact(BuildContext context) async {
    final txns = await ref.read(dbProvider).getActiveTransactionsForContact(widget.contact.id);
    if (txns > 0) {
      if (!context.mounted) return;
      AppTheme.showSnackBar(context, 'Cannot delete — $txns transaction(s) exist. Delete them first.', backgroundColor: AppTheme.debitRed);
      return;
    }

    if (!context.mounted) return;
    final confirmed = await DeleteConfirmDialog.show(
      context: context,
      title: 'Delete Contact?',
      message: 'Are you sure you want to delete "${widget.contact.name}"?',
    );
    if (confirmed == true && context.mounted) {
      final db = ref.read(dbProvider);
      await db.softDeleteContact(widget.contact.id);
      ref.read(syncEngineProvider).triggerSync();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _confirmDeleteAllTransactions(BuildContext context) async {
    final confirmed = await DeleteConfirmDialog.show(
      context: context,
      title: 'Delete All Transactions?',
      message: 'This will permanently delete all transactions with "${widget.contact.name}". This cannot be undone.',
      confirmLabel: 'Delete All',
    );
    if (confirmed == true && context.mounted) {
      final db = ref.read(dbProvider);
      final txns = await db.getActiveTransactionListForContact(widget.contact.id);
      for (final txn in txns) {
        await db.softDeleteTransaction(txn.id);
      }
      await db.upsertContact(widget.contact.copyWith(
        updatedAt: DateTime.now(),
        isDirty: true,
      ));
      ref.read(syncEngineProvider).triggerSync();
    }
  }

  Future<void> _confirmDeleteAllTransactionsAndContact(BuildContext context) async {
    final confirmed = await DeleteConfirmDialog.show(
      context: context,
      title: 'Delete Everything?',
      message: 'This will permanently delete all transactions and remove "${widget.contact.name}" from your contacts. This cannot be undone.',
      confirmLabel: 'Delete All',
    );
    if (confirmed == true && context.mounted) {
      final db = ref.read(dbProvider);
      final txns = await db.getActiveTransactionListForContact(widget.contact.id);
      for (final txn in txns) {
        await db.softDeleteTransaction(txn.id);
      }
      await db.softDeleteContact(widget.contact.id);
      ref.read(syncEngineProvider).triggerSync();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _confirmArchiveContact(BuildContext context, double balance) async {
    final isSettled = balance == 0;
    final message = isSettled
        ? 'Archive "${widget.contact.name}"? They will be hidden from your contacts but all data will be preserved.'
        : 'Archive "${widget.contact.name}"? They have an outstanding balance of ${AppTheme.formatAmount(balance.abs())} ${balance > 0 ? '(they owe you)' : '(you owe them)'}. Archiving will hide them from your contacts but preserve all data.';

    final confirmed = await DeleteConfirmDialog.show(
      context: context,
      title: 'Archive Contact?',
      message: message,
      confirmLabel: 'Archive',
      icon: Icons.archive_outlined,
      iconColor: AppTheme.primary,
      confirmColor: AppTheme.primary,
    );

    if (confirmed == true && context.mounted) {
      final db = ref.read(dbProvider);
      await db.archiveContact(widget.contact.id);
      ref.read(syncEngineProvider).triggerSync();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _confirmUnarchiveContact(BuildContext context) async {
    final confirmed = await DeleteConfirmDialog.show(
      context: context,
      title: 'Unarchive Contact?',
      message: 'Restore "${widget.contact.name}" to your active contacts?',
      confirmLabel: 'Unarchive',
      icon: Icons.unarchive_outlined,
      iconColor: AppTheme.primary,
      confirmColor: AppTheme.primary,
    );

    if (confirmed == true && context.mounted) {
      final db = ref.read(dbProvider);
      await db.unarchiveContact(widget.contact.id);
      ref.read(syncEngineProvider).triggerSync();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _editContact(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddContactScreen(
          userId: widget.userId,
          contactToEdit: widget.contact,
        ),
      ),
    );
  }

  Future<bool?> _confirmDeleteTransactionDialog(BuildContext context, TransactionModel txn) {
    return DeleteConfirmDialog.show(
      context: context,
      title: 'Delete Entry?',
      message: 'Delete this transaction of ${AppTheme.formatAmount(txn.amount)}?',
    );
  }

  Future<void> _deleteTransaction(WidgetRef ref, TransactionModel txn) async {
    final db = ref.read(dbProvider);
    await db.softDeleteTransaction(txn.id);
    await db.upsertContact(widget.contact.copyWith(
      updatedAt: DateTime.now(),
      isDirty: true,
    ));
    ref.read(syncEngineProvider).triggerSync();
  }

  void _confirmDeleteTransaction(BuildContext context, WidgetRef ref, TransactionModel txn) async {
    final confirmed = await _confirmDeleteTransactionDialog(context, txn);
    if (confirmed == true) {
      await _deleteTransaction(ref, txn);
    }
  }

  void _copyPaymentReminder(BuildContext context, double balance) {
    if (balance == 0) {
      AppTheme.showSnackBar(context, 'Balance is settled. No reminder needed.');
      return;
    }

    final String formattedAmt = AppTheme.formatAmount(balance.abs(), decimalDigits: ref.read(decimalDigitsProvider));
    String reminderText;

    if (balance > 0) {
      reminderText = 
          'Hello ${widget.contact.name},\n'
          'This is a friendly reminder that your outstanding balance in our ledger is $formattedAmt. '
          'Please make the payment as soon as possible. Thank you!';
    } else {
      reminderText = 
          'Hello ${widget.contact.name},\n'
          'I wanted to remind you that I owe you $formattedAmt in our ledger. '
          'I am processing the payment and will clear it soon. Thank you!';
    }

    Clipboard.setData(ClipboardData(text: reminderText)).then((_) {
      if (!context.mounted) return;
      AppTheme.showSnackBar(context, 'Reminder for ${widget.contact.name} copied to clipboard!');
    });
  }

  void _openAddTransactionSheet(BuildContext context, bool isOutflow, double currentBalance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionSheet(
          contact: widget.contact,
          userId: widget.userId,
          isOutflow: isOutflow,
          currentBalance: currentBalance,
        ),
      ),
    );
  }

  void _openEditTransactionSheet(BuildContext context, TransactionModel txn, double currentBalance) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionSheet(
          contact: widget.contact,
          userId: widget.userId,
          isOutflow: txn.type == 'give' || txn.type == 'pay',
          currentBalance: currentBalance,
          transactionToEdit: txn,
        ),
      ),
    );
  }

  void _showMonthPicker(BuildContext context, List<DateTime> uniqueMonths) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBg : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter by Month',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  tileColor: _selectedMonth == null
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : null,
                  leading: Icon(
                    Icons.all_inclusive_rounded,
                    color: _selectedMonth == null ? AppTheme.primary : AppTheme.secondaryText,
                    size: 20,
                  ),
                  title: Text(
                    'All Time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selectedMonth == null
                          ? AppTheme.primary
                          : isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  trailing: _selectedMonth == null
                      ? Icon(Icons.check_rounded, color: AppTheme.primary, size: 20)
                      : null,
                  onTap: () {
                    setState(() => _selectedMonth = null);
                    Navigator.pop(context);
                  },
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: uniqueMonths.map((month) {
                    final label = DateFormat('MMMM yyyy').format(month);
                    final isSelected = _selectedMonth != null &&
                        _selectedMonth!.year == month.year &&
                        _selectedMonth!.month == month.month;

                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        tileColor: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.08)
                            : null,
                        leading: Icon(
                          Icons.calendar_month_rounded,
                          color: isSelected ? AppTheme.primary : AppTheme.secondaryText,
                          size: 20,
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppTheme.primary
                                : isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_rounded, color: AppTheme.primary, size: 20)
                            : null,
                        onTap: () {
                          setState(() => _selectedMonth = month);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final txnsState = ref.watch(transactionsStreamProvider(widget.contact.id));
    final contactState = ref.watch(contactByIdProvider(widget.contact.id));
    final contact = contactState.asData?.value ?? widget.contact;
    final decDig = ref.watch(decimalDigitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contact.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.textPrimary,
              ),
            ),
            if (contact.phone != null)
              Text(
                contact.phone!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ),
          ],
        ),
        actions: [
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

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkBorder.withValues(alpha: 0.5)
                        : AppTheme.lightBorder.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    onTap: () => _showMonthPicker(context, uniqueMonths),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 14, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            filterLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : AppTheme.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          txnsState.maybeWhen(
            data: (txns) {
              final hasTxns = txns.isNotEmpty;
              final balance = _calculateContactBalance(txns);
              return PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
                position: PopupMenuPosition.under,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.15),
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkCard
                    : Colors.white,
                onSelected: (value) {
                  if (value == 'delete') {
                    _confirmDeleteContact(context);
                  } else if (value == 'delete_all_txns') {
                    _confirmDeleteAllTransactions(context);
                  } else if (value == 'delete_all_txns_and_contact') {
                    _confirmDeleteAllTransactionsAndContact(context);
                  } else if (value == 'edit') {
                    _editContact(context);
                  } else if (value == 'archive') {
                    _confirmArchiveContact(context, balance);
                  } else if (value == 'unarchive') {
                    _confirmUnarchiveContact(context);
                  }
                },
                itemBuilder: (context) => [
                  if (hasTxns)
                    PopupMenuItem(
                      value: 'delete_all_txns',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep_outlined, size: 18, color: AppTheme.debitRed),
                          const SizedBox(width: 10),
                          const Text('Delete All Transactions'),
                        ],
                      ),
                    ),
                  if (hasTxns)
                    PopupMenuItem(
                      value: 'delete_all_txns_and_contact',
                      child: Row(
                        children: [
                          Icon(Icons.person_remove_outlined, size: 18, color: AppTheme.debitRed),
                          const SizedBox(width: 10),
                          const Text('Delete Transactions & Contact'),
                        ],
                      ),
                    ),
                  if (!hasTxns)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.debitRed),
                          const SizedBox(width: 10),
                          const Text('Delete Contact'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                        const SizedBox(width: 10),
                        const Text('Edit Contact'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  if (hasTxns && !widget.contact.isArchived)
                    PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 10),
                          const Text('Archive Contact'),
                        ],
                      ),
                    ),
                  if (hasTxns && widget.contact.isArchived)
                    PopupMenuItem(
                      value: 'unarchive',
                      child: Row(
                        children: [
                          Icon(Icons.unarchive_outlined, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 10),
                          const Text('Unarchive Contact'),
                        ],
                      ),
                    ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: txnsState.when(
        data: (txns) {
          final lifetimeBalance = _calculateContactBalance(txns);

          final uniqueMonths = txns
              .map((t) => DateTime(t.date.year, t.date.month))
              .toSet()
              .toList();
          uniqueMonths.sort((a, b) => b.compareTo(a));

          final filteredTxns = _selectedMonth == null
              ? txns
              : txns.where((t) {
                  return t.date.year == _selectedMonth!.year &&
                      t.date.month == _selectedMonth!.month;
                }).toList();

          final displayBalance = _calculateContactBalance(filteredTxns);

          final totalPaid = filteredTxns
              .where((t) => t.type == 'give' || t.type == 'pay')
              .fold<double>(0, (sum, t) => sum + t.amount);
          final totalReceived = filteredTxns
              .where((t) => t.type == 'take' || t.type == 'receive')
              .fold<double>(0, (sum, t) => sum + t.amount);

          return Column(
            children: [
              // Summary card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                decoration: AppTheme.cardDecoration(
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Top: Balance row (1 line)
                    Stack(
                      children: [
                        Center(
                          child: Text(
                            AppTheme.formatAmount(displayBalance.abs(), decimalDigits: decDig),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: displayBalance > 0
                                  ? AppTheme.creditGreen
                                  : displayBalance < 0
                                      ? AppTheme.debitRed
                                      : Theme.of(context).brightness == Brightness.dark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.lightTextSecondary,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Text(
                              displayBalance > 0
                                  ? 'To Receive'
                                  : displayBalance < 0
                                      ? 'To Pay'
                                      : 'Settled',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: (Theme.of(context).brightness == Brightness.dark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.textSecondary)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                        if (displayBalance != 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: IconButton(
                                onPressed: () => _copyPaymentReminder(context, lifetimeBalance),
                                icon: Icon(
                                  Icons.content_copy_rounded,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.lightTextSecondary,
                                  size: 18,
                                ),
                                tooltip: 'Copy Reminder',
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkBorder
                          : AppTheme.lightBorder,
                      height: 1,
                    ),
                    const SizedBox(height: 8),
                    // Bottom: Paid / Received boxes
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.debitRed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.debitRed.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.debitRed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Total Paid',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.debitRed.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppTheme.formatAmount(totalPaid, decimalDigits: decDig),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.debitRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.creditGreen.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.creditGreen.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.creditGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Total Received',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.creditGreen.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppTheme.formatAmount(totalReceived, decimalDigits: decDig),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.creditGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_selectedMonth != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transactions in ${DateFormat('MMMM yyyy').format(_selectedMonth!)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _selectedMonth = null),
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                                  ? 'No transactions this month.'
                                  : 'No transactions yet.',
                              style: const TextStyle(color: AppTheme.secondaryText),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        children: filteredTxns.map((txn) {
                          final dateStr = DateFormat('dd MMM yyyy').format(txn.date);

                                String typeLabel;
                                IconData typeIcon;
                                Color typeColor;
                                switch (txn.type) {
                                  case 'give':
                                    typeLabel = 'Paid';
                                    typeIcon = Icons.call_made_rounded;
                                    typeColor = AppTheme.debitRed;
                                    break;
                                  case 'take':
                                    typeLabel = 'Received';
                                    typeIcon = Icons.call_received_rounded;
                                    typeColor = AppTheme.creditGreen;
                                    break;
                                  case 'receive':
                                    typeLabel = 'Received';
                                    typeIcon = Icons.call_received_rounded;
                                    typeColor = AppTheme.creditGreen;
                                    break;
                                  case 'return':
                                    typeLabel = 'Returned';
                                    typeIcon = Icons.call_received_rounded;
                                    typeColor = AppTheme.creditGreen;
                                    break;
                                  case 'pay':
                                    typeLabel = 'Paid';
                                    typeIcon = Icons.call_made_rounded;
                                    typeColor = AppTheme.debitRed;
                                    break;
                                  default:
                                    typeLabel = txn.type;
                                    typeIcon = Icons.circle_rounded;
                                    typeColor = AppTheme.secondaryText;
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _openEditTransactionSheet(context, txn, lifetimeBalance),
                                      onLongPress: () => _confirmDeleteTransaction(context, ref, txn),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? AppTheme.darkCard
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? AppTheme.darkBorder.withValues(alpha: 0.5)
                                                : AppTheme.lightBorder.withValues(alpha: 0.8),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.04),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(typeIcon, size: 18, color: typeColor),
                                                const SizedBox(width: 10),
                                                Text(
                                                  AppTheme.formatAmount(txn.amount, decimalDigits: decDig),
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: typeColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: typeColor.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    typeLabel,
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w700,
                                                      color: typeColor,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  dateStr,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? AppTheme.darkTextSecondary.withValues(alpha: 0.7)
                                                        : AppTheme.lightTextSecondary.withValues(alpha: 0.7),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (txn.description != null && txn.description!.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const SizedBox(width: 28),
                                                  Icon(
                                                    Icons.description_outlined,
                                                    size: 13,
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? AppTheme.darkTextSecondary.withValues(alpha: 0.5)
                                                        : AppTheme.lightTextSecondary.withValues(alpha: 0.5),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      txn.description!,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).brightness == Brightness.dark
                                                            ? AppTheme.darkTextSecondary
                                                            : AppTheme.lightTextSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Could not load transactions. Pull down to refresh.')),
      ),
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
            padding: EdgeInsets.fromLTRB(
              16, 12, 16,
              12 + MediaQuery.of(context).viewPadding.bottom,
            ),
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
                        Text('Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                        Text('Received', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
