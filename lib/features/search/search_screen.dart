import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/local_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../ledger/ledger_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contactsAsync = ref.watch(contactsStreamProvider(userId));
    final txnsAsync = ref.watch(allTransactionsStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Ledger'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'Search by amount, name, phone or description...',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: contactsAsync.when(
              data: (contacts) => txnsAsync.when(
                data: (txns) {
                  final q = _query.toLowerCase().trim();
                  if (q.isEmpty) {
                    return _emptyState(
                      isDark,
                      Icons.search_rounded,
                      'Search by amount, name, phone or description',
                    );
                  }

                  final contactMap = {for (final c in contacts) c.id: c};
                  final qNum = double.tryParse(q);
                  final showExactMatches = qNum != null;

                  final matchedTxns = <({TransactionModel txn, int priority})>[];
                  final matchedContactIds = <String>{};

                  for (final t in txns) {
                    final c = contactMap[t.contactId];
                    final contactName = c?.name.toLowerCase() ?? '';
                    final amountStr = t.amount.toStringAsFixed(0);

                    int? priority;

                    if (showExactMatches && t.amount == qNum) {
                      priority = 0;
                    } else if (amountStr.contains(q)) {
                      priority = 1;
                    } else if (t.description?.toLowerCase().contains(q) == true) {
                      priority = 2;
                    } else if (contactName.contains(q) || (c?.phone ?? '').contains(q)) {
                      priority = 3;
                    }

                    if (priority != null) {
                      matchedTxns.add((txn: t, priority: priority));
                      matchedContactIds.add(t.contactId);
                    }
                  }

                  matchedTxns.sort((a, b) => a.priority.compareTo(b.priority));

                  final nameMatchedContacts = contacts.where((c) {
                    if (matchedContactIds.contains(c.id)) return false;
                    if (c.name.toLowerCase().contains(q)) return true;
                    if ((c.phone ?? '').contains(q)) return true;
                    return false;
                  }).toList();

                  if (matchedTxns.isEmpty && nameMatchedContacts.isEmpty) {
                    return _emptyState(isDark, Icons.search_off_rounded, 'No results found for "$_query"');
                  }

                  return ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    children: [
                      if (matchedTxns.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            'TRANSACTIONS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        ...matchedTxns.map((m) =>
                            _txnTile(context, m.txn, contactMap[m.txn.contactId], isDark)),
                      ],
                      if (nameMatchedContacts.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                          child: Text(
                            'CONTACTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        ...nameMatchedContacts.map((c) =>
                            _compactContactTile(context, c, isDark)),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                error: (e, _) => Center(child: Text('$e')),
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _txnTile(BuildContext context, TransactionModel txn, Contact? contact, bool isDark) {
    final isGive = txn.type == 'give';
    final isTake = txn.type == 'take';
    final isReceive = txn.type == 'receive';
    final isPay = txn.type == 'pay';

    final isPositive = isGive || isPay;
    final label = isGive ? 'Gave' : isTake ? 'Took' : isReceive ? 'Returned' : 'Repaid';
    final labelColor = isPositive ? AppTheme.creditGreen : AppTheme.debitRed;
    final labelBg = isPositive ? AppTheme.creditGreenBg : AppTheme.debitRedBg;

    final initial = contact != null && contact.name.trim().isNotEmpty
        ? contact.name.trim().substring(0, 1).toUpperCase()
        : '?';

    final dateStr = '${txn.date.day} ${_monthAbbr(txn.date.month)} ${txn.date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          if (contact != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LedgerScreen(contact: contact, userId: ref.read(userIdProvider)),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: AppTheme.glassmorphicBox(context: context),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : AppTheme.primary.withValues(alpha: 0.12),
                foregroundColor: isDark ? AppTheme.primaryLight : AppTheme.primary,
                child: Text(initial,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact?.name ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: labelBg.withValues(alpha: isDark ? 0.2 : 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: labelColor,
                            ),
                          ),
                        ),
                        if (txn.description?.isNotEmpty == true) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              txn.description!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppTheme.formatAmount(txn.amount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactContactTile(BuildContext context, Contact contact, bool isDark) {
    final initial = contact.name.trim().isNotEmpty
        ? contact.name.trim().substring(0, 1).toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LedgerScreen(contact: contact, userId: ref.read(userIdProvider)),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: AppTheme.glassmorphicBox(context: context),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : AppTheme.primary.withValues(alpha: 0.12),
                foregroundColor: isDark ? AppTheme.primaryLight : AppTheme.primary,
                child: Text(initial,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  contact.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
              ),
              if (contact.phone != null)
                Text(
                  contact.phone!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.secondaryText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(bool isDark, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48,
              color: (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary).withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _monthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
