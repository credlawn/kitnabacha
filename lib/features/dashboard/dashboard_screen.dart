import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/local_db.dart';
import '../../core/providers.dart';
import '../../core/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../ledger/ledger_screen.dart';
import '../contacts/add_contact_screen.dart';
import '../expense/expense_dashboard.dart';
import '../expense/widgets/add_expense_sheet.dart';
import '../search/search_screen.dart';
import '../search/expense_search_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final String userId;

  const DashboardScreen({super.key, required this.userId});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentTab = 0;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _currentTab = ref.read(defaultTabProvider);
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Calculate net balances for dashboard summary
  Map<String, double> _calculateBalances(
    List<Contact> contacts,
    List<TransactionModel> txns,
  ) {
    double totalReceivable = 0;
    double totalPayable = 0;

    for (final contact in contacts) {
      // Get all transactions for this contact
      final contactTxns = txns.where((t) => t.contactId == contact.id).toList();
      
      double netBalance = 0;
      for (final txn in contactTxns) {
        if (txn.type == 'give') {
          netBalance += txn.amount; // Lent money
        } else if (txn.type == 'pay') {
          netBalance += txn.amount; // Paid back loan we took
        } else if (txn.type == 'take') {
          netBalance -= txn.amount; // Borrowed money
        } else if (txn.type == 'receive') {
          netBalance -= txn.amount; // Received part-payment of loan we gave
        }
      }

      if (netBalance > 0) {
        totalReceivable += netBalance;
      } else if (netBalance < 0) {
        totalPayable += netBalance.abs();
      }
    }

    return {
      'receivable': totalReceivable,
      'payable': totalPayable,
      'net': totalReceivable - totalPayable,
    };
  }

  void _openAddContactScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddContactScreen(userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regularContactsState = ref.watch(contactsStreamProvider(widget.userId));
    final archivedContactsState = ref.watch(archivedContactsStreamProvider(widget.userId));
    final contactsState = _showArchived ? archivedContactsState : regularContactsState;
    final txnsState = ref.watch(allTransactionsStreamProvider(widget.userId));
    final decDig = ref.watch(decimalDigitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.primary,
                ),
                children: [
                  TextSpan(text: 'Ledge', style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.primary,
                  )),
                  TextSpan(text: 'o', style: TextStyle(
                    color: AppTheme.creditGreen,
                  )),
                ],
              ),
            ),
            Text(
              _currentTab == 0 ? 'Personal Ledger' : 'Expense Tracker',
              style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.primary),
            tooltip: 'Search',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _currentTab == 0
                      ? const SearchScreen()
                      : const ExpenseSearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person_rounded, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.primary),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _currentTab == 0
          ? contactsState.when(
              data: (displayContacts) => txnsState.when(
                data: (txns) {
                  final regularContacts = regularContactsState.asData?.value ?? [];
                  final balances = _calculateBalances(regularContacts, txns);
                  final net = balances['net']!;
                  final receivable = balances['receivable']!;
                  final payable = balances['payable']!;

                  return CustomScrollView(
                    slivers: [
                        // 1. Dashboard Financial Summary Card
                        SliverPadding(
                          padding: const EdgeInsets.all(16.0),
                          sliver: SliverToBoxAdapter(
                            child: Container(
                              decoration: AppTheme.cardDecoration(
                                isDark: Theme.of(context).brightness == Brightness.dark,
                              ),
                              padding: const EdgeInsets.all(16),
                              child: receivable == 0 && payable == 0
                                  ? Center(
                                      child: Text(
                                        'All settled',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? AppTheme.darkTextSecondary
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                    )
                                  : Column(
                                        children: [
                                          Stack(
                                            children: [
                                              Center(
                                                child: Text(
                                                  AppTheme.formatAmount(net.abs(), decimalDigits: decDig),
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                    color: net == 0
                                                        ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)
                                                        : net > 0
                                                            ? AppTheme.creditGreen
                                                            : AppTheme.debitRed,
                                                  ),
                                                ),
                                              ),
                                              if (net != 0)
                                                Positioned(
                                                  left: 0,
                                                  top: 0,
                                                  bottom: 0,
                                                  child: Center(
                                                    child: Text(
                                                      net > 0 ? 'To Receive' : 'To Pay',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: (Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.textSecondary).withValues(alpha: 0.7),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 10),
                                        Divider(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? AppTheme.darkBorder
                                              : AppTheme.lightBorder,
                                          height: 1,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.debitRed.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(12),
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
                                                          width: 8,
                                                          height: 8,
                                                          decoration: const BoxDecoration(
                                                            color: AppTheme.debitRed,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'To Pay',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: AppTheme.debitRed.withValues(alpha: 0.8),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      AppTheme.formatAmount(payable, decimalDigits: decDig),
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.w900,
                                                        color: AppTheme.debitRed,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.creditGreen.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(12),
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
                                                          width: 8,
                                                          height: 8,
                                                          decoration: const BoxDecoration(
                                                            color: AppTheme.creditGreen,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          'To Receive',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: AppTheme.creditGreen.withValues(alpha: 0.8),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      AppTheme.formatAmount(receivable, decimalDigits: decDig),
                                                      style: const TextStyle(
                                                        fontSize: 18,
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
                          ),
                        ),

                        // 2. Contacts Header
                        SliverPadding(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 8),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              children: [
                                Text(
                                  _showArchived ? 'Archived Contacts' : 'Contacts',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? AppTheme.secondaryText
                                        : AppTheme.lightTextSecondary,
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: () {
                                    setState(() => _showArchived = !_showArchived);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _showArchived
                                          ? AppTheme.primary.withValues(alpha: 0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _showArchived
                                            ? AppTheme.primary.withValues(alpha: 0.3)
                                            : (Theme.of(context).brightness == Brightness.dark
                                                ? AppTheme.darkBorder
                                                : AppTheme.lightBorder),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _showArchived ? Icons.people_outline_rounded : Icons.archive_outlined,
                                          size: 14,
                                          color: _showArchived ? AppTheme.primary : AppTheme.secondaryText,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _showArchived ? 'Show Active' : 'Archived',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _showArchived ? AppTheme.primary : AppTheme.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 3. Contacts list
                        displayContacts.isEmpty
                            ? SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.people_outline_rounded,
                                          size: 48,
                                          color: AppTheme.secondaryText,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _showArchived
                                              ? 'No archived contacts'
                                              : 'No contacts yet.\nTap + to add your first contact!',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : SliverToBoxAdapter(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: AppTheme.glassmorphicBox(context: context),
                                  child: Column(
                                    children: [
                                      for (int i = 0; i < displayContacts.length; i++)
                                        _buildContactTile(
                                          contact: displayContacts[i],
                                          txns: txns,
                                          index: i,
                                          total: displayContacts.length,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          // extra space so last contact clears the center + button
                          SliverToBoxAdapter(
                            child: SizedBox(height: 32),
                          ),
                        ],
                      );
                    },
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                error: (e, _) => Center(child: Text('Error loading transactions: $e')),
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (e, _) => Center(child: Text('Error loading contacts: $e')),
            )
          : ExpenseDashboard(userId: widget.userId),
      floatingActionButton: null,
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkBorder
                      : AppTheme.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkBg
                    : AppTheme.lightBg,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkBorder
                        : AppTheme.lightBorder,
                    width: 0.5,
                  ),
                ),
              ),
              padding: EdgeInsets.only(top: 6, bottom: MediaQuery.of(context).viewPadding.bottom + 4),
              child: Row(
                children: [
                  _navItem(
                    context: context,
                    icon: Icons.menu_book_rounded,
                    label: 'Ledger',
                    selected: _currentTab == 0,
                    onTap: () => setState(() => _currentTab = 0),
                  ),
                  _navItem(
                    context: context,
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Expenses',
                    selected: _currentTab == 1,
                    onTap: () => setState(() => _currentTab = 1),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -24,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _currentTab == 0 ? _openAddContactScreen : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseSheet(userId: widget.userId),
                    ),
                  );
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile({
    required Contact contact,
    required List<TransactionModel> txns,
    required int index,
    required int total,
  }) {
    final cTxns = txns.where((t) => t.contactId == contact.id).toList();
    final cDecDig = ref.read(decimalDigitsProvider);
    double cBalance = 0;
    for (final txn in cTxns) {
      if (txn.type == 'give' || txn.type == 'pay') {
        cBalance += txn.amount;
      } else {
        cBalance -= txn.amount;
      }
    }

    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LedgerScreen(
                  contact: contact,
                  userId: widget.userId,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.primary.withValues(alpha: 0.2)
                      : AppTheme.primary.withValues(alpha: 0.12),
                  foregroundColor: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.primaryLight
                      : AppTheme.primary,
                  radius: 22,
                  child: Text(
                    contact.name.trim().isNotEmpty
                        ? contact.name.trim().substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (contact.phone != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          contact.phone!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      cBalance == 0
                          ? 'Settled'
                          : AppTheme.formatAmount(cBalance.abs(), decimalDigits: cDecDig),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: cBalance > 0
                            ? AppTheme.creditGreen
                            : cBalance < 0
                                ? AppTheme.debitRed
                                : AppTheme.secondaryText,
                      ),
                    ),
                    if (cBalance != 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        cBalance > 0 ? 'Receivable' : 'Payable',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cBalance > 0
                              ? AppTheme.creditGreen.withValues(alpha: 0.7)
                              : AppTheme.debitRed.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.secondaryText,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (index < total - 1)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkBorder.withValues(alpha: 0.5)
                : AppTheme.lightBorder,
          ),
      ],
    );
  }

  Widget _navItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = selected ? AppTheme.primary : (isDark ? AppTheme.darkNavUnselected : AppTheme.navUnselected);
    final textColor = selected ? AppTheme.primary : (isDark ? AppTheme.darkNavUnselected : AppTheme.navUnselected);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
