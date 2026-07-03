import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/local_db.dart';
import '../../core/providers.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_screen.dart';
import '../ledger/ledger_screen.dart';
import '../expense/expense_dashboard.dart';
import '../expense/widgets/add_expense_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final String userId;

  const DashboardScreen({super.key, required this.userId});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentTab = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Calculate net balances for dashboard summary
  Map<String, double> _calculateBalances(
    List<Contact> contacts,
    List<TransactionModel> txns,
  ) {
    double totalReceivable = 0; // Kitna Lena Hai (Sum of positive contact balances)
    double totalPayable = 0;    // Kitna Dena Hai (Sum of negative contact balances)

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

  // Build the Sync Status Indicator widget
  Widget _buildSyncIndicator(SyncStatus status) {
    IconData icon;
    Color color;
    String label;
    bool isSpinning = false;

    switch (status) {
      case SyncStatus.synced:
        icon = Icons.cloud_done_rounded;
        color = AppTheme.creditGreen;
        label = 'Synced';
        break;
      case SyncStatus.syncing:
        icon = Icons.sync_rounded;
        color = AppTheme.warningOrange;
        label = 'Syncing...';
        isSpinning = true;
        break;
      case SyncStatus.offline:
        icon = Icons.cloud_off_rounded;
        color = AppTheme.secondaryText;
        label = 'Offline Mode';
        break;
      case SyncStatus.error:
        icon = Icons.cloud_sync_rounded;
        color = AppTheme.debitRed;
        label = 'Sync Failed';
        break;
    }

    return InkWell(
      onTap: () => ref.read(syncEngineProvider).triggerSync(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isSpinning
                ? SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
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

  void _showAuthModal() {
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
            padding: const EdgeInsets.only(top: 8),
            child: const AuthScreen(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsState = ref.watch(contactsStreamProvider(widget.userId));
    final txnsState = ref.watch(allTransactionsStreamProvider(widget.userId));
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('कितना बचा ?'),
            Text(
              'Hisab Kitab Ledger',
              style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
            ),
          ],
        ),
        actions: [
          if (widget.userId != 'guest') ...[
            _buildSyncIndicator(syncStatus),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Logout',
              onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            ),
          ] else
            TextButton.icon(
              onPressed: _showAuthModal,
              icon: const Icon(Icons.cloud_upload_rounded, color: AppTheme.primaryLight),
              label: const Text('Backup Now', style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 8),
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

                  // Filter contacts by search query
                  final filteredContacts = contacts.where((contact) {
                    return contact.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        (contact.phone ?? '').contains(_searchQuery);
                  }).toList();

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
                              decoration: AppTheme.glassmorphicBox(
                                context: context,
                                gradient: net >= 0
                                    ? (net > 0
                                        ? AppTheme.greenCardGradient
                                        : (Theme.of(context).brightness == Brightness.dark
                                            ? AppTheme.premiumCardGradient
                                            : AppTheme.premiumCardLightGradient))
                                    : AppTheme.redCardGradient,
                              ),
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  const Text(
                                    'NET OUTSTANDING',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white70,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    AppTheme.formatAmount(net.abs()),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    net > 0
                                        ? 'Lena Hai (Receivable)'
                                        : net < 0
                                            ? 'Dena Hai (Payable)'
                                            : 'No outstanding balance',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: net >= 0 ? Colors.greenAccent : Colors.redAccent,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Divider(color: Colors.white12, height: 1),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Column(
                                        children: [
                                          const Text(
                                            'Kitna Lena Hai',
                                            style: TextStyle(fontSize: 12, color: Colors.white70),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppTheme.formatAmount(receivable),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.greenAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        height: 30,
                                        width: 1,
                                        color: Colors.white12,
                                      ),
                                      Column(
                                        children: [
                                          const Text(
                                            'Kitna Dena Hai',
                                            style: TextStyle(fontSize: 12, color: Colors.white70),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppTheme.formatAmount(payable),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.redAccent,
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

                        // 1b. Guest Warning Banner
                        if (widget.userId == 'guest')
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                              child: InkWell(
                                onTap: _showAuthModal,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: AppTheme.glassmorphicBox(
                                    context: context,
                                    color: AppTheme.warningOrange.withValues(alpha: 0.08),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.cloud_off_rounded, color: AppTheme.warningOrange, size: 24),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Cloud Backup is Disabled',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white
                                                    : AppTheme.lightTextPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Save your ledger to the cloud to prevent data loss.',
                                              style: TextStyle(
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? AppTheme.secondaryText
                                                    : AppTheme.lightTextSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warningOrange.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'Sync Now',
                                          style: TextStyle(
                                            color: AppTheme.warningOrange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // 2. Search Box
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          sliver: SliverToBoxAdapter(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Search contacts by name or phone...',
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppTheme.secondaryText
                                      : AppTheme.lightTextSecondary,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),

                        // 3. Contacts Header
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

                        // 4. Contacts list
                        filteredContacts.isEmpty
                            ? SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _searchQuery.isNotEmpty
                                              ? Icons.search_off_rounded
                                              : Icons.people_outline_rounded,
                                          size: 48,
                                          color: AppTheme.secondaryText.withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'No matching contacts found'
                                              : 'Aapne abhi tak koi contact add nahi kiya hai.',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: AppTheme.secondaryText),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final contact = filteredContacts[index];

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
                                                            ? Colors.white
                                                            : AppTheme.lightTextPrimary,
                                                      ),
                                                    ),
                                                    if (contact.phone != null) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        contact.phone!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Theme.of(context).brightness == Brightness.dark
                                                              ? AppTheme.secondaryText
                                                              : AppTheme.lightTextSecondary,
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
                                                      cBalance > 0 ? 'Lena Hai' : 'Dena Hai',
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
                                  childCount: filteredContacts.length,
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
              label: 'Ledger (हिसाब)',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_rounded),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary),
              label: 'Expenses (खर्चा)',
            ),
          ],
        ),
      ),
    );
  }
}
