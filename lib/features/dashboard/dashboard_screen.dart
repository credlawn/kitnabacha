import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/local_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../ledger/ledger_screen.dart';
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

  // Show Bottom Sheet to Add a New Contact locally-first
  void _showAddContactSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkBorder
                      : AppTheme.lightBorder,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add New Contact',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter name (e.g. Ramesh Kumar)',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      hintText: 'Enter mobile number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final db = ref.read(dbProvider);
                      final contact = Contact(
                        id: const Uuid().v4(),
                        userId: widget.userId,
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                        isDirty: true,
                        isDeleted: false,
                      );

                      // Save in Drift immediately (reactive UI updates automatically)
                      await db.upsertContact(contact);

                      // Trigger async sync in the background
                      ref.read(syncEngineProvider).triggerSync();

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Contact',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsState = ref.watch(contactsStreamProvider(widget.userId));
    final txnsState = ref.watch(allTransactionsStreamProvider(widget.userId));

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
              data: (contacts) => txnsState.when(
                data: (txns) {
                  final balances = _calculateBalances(contacts, txns);
                  final net = balances['net']!;
                  final receivable = balances['receivable']!;
                  final payable = balances['payable']!;

                  return RefreshIndicator(
                    onRefresh: () => ref.read(syncEngineProvider).triggerSync(),
                    color: AppTheme.primary,
                    child: CustomScrollView(
                      slivers: [
                        // 1. Dashboard Financial Summary Card
                        SliverPadding(
                          padding: const EdgeInsets.all(16.0),
                          sliver: SliverToBoxAdapter(
                            child: Container(
                              decoration: AppTheme.cardDecoration(
                                isDark: Theme.of(context).brightness == Brightness.dark,
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        AppTheme.formatAmount(net.abs()),
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          color: net == 0
                                              ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)
                                              : net > 0
                                                  ? AppTheme.creditGreen
                                                  : AppTheme.debitRed,
                                        ),
                                      ),
                                      if (net != 0) ...[
                                        const SizedBox(width: 8),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 3),
                                          child: Text(
                                            net > 0 ? 'Receivable' : 'Payable',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: (Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.textSecondary).withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: Divider(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? AppTheme.darkBorder
                                          : AppTheme.lightBorder,
                                      height: 1,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Column(
                                        children: [
                                          Text(
                                            'Total Receivable',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppTheme.formatAmount(receivable),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.creditGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        height: 28,
                                        width: 1,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? AppTheme.darkBorder
                                            : AppTheme.lightBorder,
                                      ),
                                      Column(
                                        children: [
                                          Text(
                                            'Total Payable',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppTheme.formatAmount(payable),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.debitRed,
                                            ),
                                          ),
                                        ],
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
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 8),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              'MY CONTACTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppTheme.secondaryText
                                    : AppTheme.lightTextSecondary,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),

                        // 3. Contacts list
                        contacts.isEmpty
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
                                          'No contacts yet.\nTap + to add your first contact!',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final contact = contacts[index];

                                    // Calculate contact-specific balance
                                    final cTxns = txns.where((t) => t.contactId == contact.id).toList();
                                    double cBalance = 0;
                                    for (final txn in cTxns) {
                                      if (txn.type == 'give' || txn.type == 'pay') {
                                        cBalance += txn.amount;
                                      } else {
                                        cBalance -= txn.amount;
                                      }
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                                      child: InkWell(
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
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          decoration: AppTheme.glassmorphicBox(context: context),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Row(
                                            children: [
                                              // Contact Initials Avatar
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

                                              // Name and Phone details
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

                                              // Balance indicator
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    cBalance == 0
                                                        ? 'Settled'
                                                        : AppTheme.formatAmount(cBalance.abs()),
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
                                    );
                                  },
                                  childCount: contacts.length,
                                ),
                              ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                error: (e, _) => Center(child: Text('Error loading transactions: $e')),
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (e, _) => Center(child: Text('Error loading contacts: $e')),
            )
          : ExpenseDashboard(userId: widget.userId),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddContactSheet,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AddExpenseSheet(userId: widget.userId),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      bottomNavigationBar: Container(
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
        child: NavigationBar(
          selectedIndex: _currentTab,
          onDestinationSelected: (idx) => setState(() => _currentTab = idx),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkBg
              : AppTheme.lightBg,
          indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.menu_book_rounded),
              selectedIcon: Icon(Icons.menu_book_rounded, color: AppTheme.primary),
              label: 'Ledger',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_rounded),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary),
              label: 'Expenses',
            ),
          ],
        ),
      ),
    );
  }
}
