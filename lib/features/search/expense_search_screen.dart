import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class ExpenseSearchScreen extends ConsumerStatefulWidget {
  const ExpenseSearchScreen({super.key});

  @override
  ConsumerState<ExpenseSearchScreen> createState() => _ExpenseSearchScreenState();
}

class _ExpenseSearchScreenState extends ConsumerState<ExpenseSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const _iconMap = <String, IconData>{
    'restaurant_rounded': Icons.restaurant_rounded,
    'shopping_bag_rounded': Icons.shopping_bag_rounded,
    'directions_car_rounded': Icons.directions_car_rounded,
    'receipt_long_rounded': Icons.receipt_long_rounded,
    'movie_filter_rounded': Icons.movie_filter_rounded,
    'medical_services_rounded': Icons.medical_services_rounded,
    'category_rounded': Icons.category_rounded,
  };

  IconData _iconFromString(String name) => _iconMap[name] ?? Icons.category_rounded;
  Color _colorFromHex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF${h.length == 6 ? h : '000000'}', radix: 16));
  }

  String _monthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expensesAsync = ref.watch(expensesStreamProvider(userId));
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Expenses'),
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
                hintText: 'Search by category, description or amount...',
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
            child: expensesAsync.when(
              data: (expenses) => categoriesAsync.when(
                data: (categories) {
                  final catMap = {for (final c in categories) c.id: c};

                  final q = _query.toLowerCase().trim();
                  if (q.isEmpty) {
                    return _emptyState(isDark, 'Type to search your expenses');
                  }

                  final results = expenses.where((e) {
                    if (e.remarks?.toLowerCase().contains(q) == true) return true;
                    final cat = catMap[e.categoryId];
                    if (cat != null && cat.name.toLowerCase().contains(q)) return true;
                    if (e.subCategory.toLowerCase().contains(q)) return true;
                    try {
                      if (e.amount.toString().contains(q)) return true;
                    } catch (_) {}
                    return false;
                  }).toList();

                  if (results.isEmpty) {
                    return _emptyState(isDark, 'No expenses found for "$_query"');
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final expense = results[index];
                      final cat = catMap[expense.categoryId];
                      final catIcon = cat != null ? _iconFromString(cat.icon) : Icons.category_rounded;
                      final catColor = cat != null ? _colorFromHex(cat.color) : AppTheme.secondaryText;
                      final dateStr = '${expense.date.day} ${_monthAbbr(expense.date.month)} ${expense.date.year}';

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Container(
                          decoration: AppTheme.glassmorphicBox(context: context),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(catIcon, size: 18, color: catColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat?.name ?? 'Unknown',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      expense.remarks?.isNotEmpty == true
                                          ? expense.remarks!
                                          : expense.subCategory,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppTheme.formatAmount(expense.amount),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.debitRed,
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
                      );
                    },
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

  Widget _emptyState(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 48,
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
}
