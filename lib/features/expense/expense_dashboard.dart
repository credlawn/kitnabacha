import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/local_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/delete_confirm_dialog.dart';
import 'categories_screen.dart';
import 'widgets/add_expense_sheet.dart';

class ExpenseDashboard extends ConsumerStatefulWidget {
  final String userId;
  const ExpenseDashboard({super.key, required this.userId});

  @override
  ConsumerState<ExpenseDashboard> createState() => _ExpenseDashboardState();
}

class _ExpenseDashboardState extends ConsumerState<ExpenseDashboard> {
  DateTime? _selectedMonth;
  String? _expandedCategoryId; // Track which category is expanded for subcategories view

  final Map<String, IconData> _availableIcons = {
    'restaurant_rounded': Icons.restaurant_rounded,
    'shopping_bag_rounded': Icons.shopping_bag_rounded,
    'directions_car_rounded': Icons.directions_car_rounded,
    'receipt_long_rounded': Icons.receipt_long_rounded,
    'movie_filter_rounded': Icons.movie_filter_rounded,
    'medical_services_rounded': Icons.medical_services_rounded,
    'home_rounded': Icons.home_rounded,
    'school_rounded': Icons.school_rounded,
    'flight_rounded': Icons.flight_rounded,
    'work_rounded': Icons.work_rounded,
    'sports_esports_rounded': Icons.sports_esports_rounded,
    'fitness_center_rounded': Icons.fitness_center_rounded,
    'local_atm_rounded': Icons.local_atm_rounded,
    'category_rounded': Icons.category_rounded,
  };

  @override
  void initState() {
    super.initState();
    // Default to current month
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  IconData _getIconFromString(String iconName) {
    return _availableIcons[iconName] ?? Icons.category_rounded;
  }

  Color _getColorFromHex(String hexColor) {
    String hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

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
                      'Filter Expenses by Month',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  void _openAddExpenseSheet(BuildContext context, {Expense? exp}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseSheet(
          userId: widget.userId,
          editExpense: exp,
        ),
      ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, Expense exp) async {
    final confirmed = await DeleteConfirmDialog.show(
      context: context,
      title: 'Delete Expense?',
      message: 'Are you sure you want to delete this expense of ${AppTheme.formatAmount(exp.amount)}?',
    );
    if (confirmed == true) {
      final db = ref.read(dbProvider);
      await db.softDeleteExpense(exp.id);
      ref.read(syncEngineProvider).triggerSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesState = ref.watch(expensesStreamProvider(widget.userId));
    final categoriesState = ref.watch(expenseCategoriesStreamProvider(widget.userId));

    return categoriesState.when(
      data: (categories) => expensesState.when(
        data: (expenses) {
          // Calculate unique months from all expenses
          final uniqueMonths = expenses
              .map((t) => DateTime(t.date.year, t.date.month))
              .toSet()
              .toList();
          uniqueMonths.sort((a, b) => b.compareTo(a));

          // Filter expenses based on selected month
          final filteredExpenses = _selectedMonth == null
              ? expenses
              : expenses.where((t) {
                  return t.date.year == _selectedMonth!.year && t.date.month == _selectedMonth!.month;
                }).toList();

          // Calculate totals
          final now = DateTime.now();
          final double totalToday = expenses
              .where((t) => t.date.year == now.year && t.date.month == now.month && t.date.day == now.day)
              .fold(0.0, (sum, item) => sum + item.amount);

          final double totalThisMonth = filteredExpenses.fold(0.0, (sum, item) => sum + item.amount);

          // Group expenses by category
          final Map<String, double> categoryTotals = {};
          final Map<String, Map<String, double>> subCategoryTotals = {};

          for (final exp in filteredExpenses) {
            final catId = exp.categoryId;
            categoryTotals[catId] = (categoryTotals[catId] ?? 0.0) + exp.amount;

            if (!subCategoryTotals.containsKey(catId)) {
              subCategoryTotals[catId] = {};
            }
            subCategoryTotals[catId]![exp.subCategory] = (subCategoryTotals[catId]![exp.subCategory] ?? 0.0) + exp.amount;
          }

          // Sort categories by highest spend
          final sortedCategoryIds = categoryTotals.keys.toList()
            ..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));

          return Column(
            children: [
              // Month filter picker row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedMonth == null
                          ? 'All Time Expenses'
                          : 'Expenses in ${DateFormat('MMMM yyyy').format(_selectedMonth!)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    TextButton.icon(
                      onPressed: () => _showMonthPicker(context, uniqueMonths),
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkBorder
                            : AppTheme.lightBorder,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded, size: 14, color: AppTheme.primary),
                      label: Text(
                        _selectedMonth == null ? 'All' : DateFormat('MMM-yy').format(_selectedMonth!),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Top Dashboard Summaries (Today vs Monthly cards)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  children: [
                    // Today's Expense
                    Expanded(
                      child: Container(
                        decoration: AppTheme.glassmorphicBox(
                          context: context,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF475569).withValues(alpha: 0.9), // Slate 600
                              const Color(0xFF334155).withValues(alpha: 0.9), // Slate 700
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "TODAY'S OUTFLOW",
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppTheme.formatAmount(totalToday),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Month's Expense
                    Expanded(
                      child: Container(
                        decoration: AppTheme.glassmorphicBox(
                          context: context,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.debitRed.withValues(alpha: 0.95),
                              const Color(0xFFC026D3).withValues(alpha: 0.95), // Deep Magenta-Fuchsia
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedMonth == null ? "LIFETIME OUTFLOW" : "THIS MONTH'S OUTFLOW",
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppTheme.formatAmount(totalThisMonth),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content body: Categories Breakdown and Transactions list
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // 1. Category-wise Spending Section Header
                    SliverPadding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SPENDING BY CATEGORY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppTheme.secondaryText
                                    : AppTheme.lightTextSecondary,
                                letterSpacing: 1.5,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CategoriesScreen(userId: widget.userId),
                                  ),
                                );
                              },
                              child: const Text(
                                'Manage Categories',
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
                    ),

                    // 2. Spending by category cards
                    sortedCategoryIds.isEmpty
                        ? const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              child: Center(
                                child: Text(
                                  'No expense transactions in this month.',
                                  style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, idx) {
                                final catId = sortedCategoryIds[idx];
                                final amount = categoryTotals[catId]!;
                                final percentage = totalThisMonth > 0 ? (amount / totalThisMonth) * 100 : 0.0;

                                // Find category details from database categories list
                                final catData = categories.firstWhere(
                                  (c) => c.id == catId,
                                  orElse: () => ExpenseCategory(
                                    id: catId,
                                    userId: widget.userId,
                                    name: 'Others',
                                    icon: 'category_rounded',
                                    color: '#90A4AE',
                                    subCategories: '[]',
                                    createdAt: DateTime.now(),
                                    updatedAt: DateTime.now(),
                                    isDirty: false,
                                    isDeleted: false,
                                  ),
                                );

                                final catColor = _getColorFromHex(catData.color);
                                final catIcon = _getIconFromString(catData.icon);
                                final isExpanded = _expandedCategoryId == catId;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _expandedCategoryId = isExpanded ? null : catId;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      decoration: AppTheme.glassmorphicBox(context: context),
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: catColor.withValues(alpha: 0.12),
                                                foregroundColor: catColor,
                                                child: Icon(catIcon, size: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      catData.name,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${percentage.toStringAsFixed(1)}% of total spend',
                                                      style: const TextStyle(color: AppTheme.secondaryText, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    AppTheme.formatAmount(amount),
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Icon(
                                                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                                    size: 16,
                                                    color: AppTheme.secondaryText,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          // Visual progress bar
                                          Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? AppTheme.darkBorder
                                                  : AppTheme.lightBorder,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: totalThisMonth > 0 ? (amount / totalThisMonth) : 0.0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: catColor,
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Subcategories details if expanded
                                          if (isExpanded && subCategoryTotals[catId] != null) ...[
                                            const SizedBox(height: 14),
                                            const Divider(height: 1),
                                            const SizedBox(height: 8),
                                            ...subCategoryTotals[catId]!.entries.map((subEntry) {
                                              final subAmt = subEntry.value;
                                              final subPct = amount > 0 ? (subAmt / amount) * 100 : 0.0;
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      '•  ${subEntry.key}',
                                                      style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                                                    ),
                                                    Text(
                                                      '${AppTheme.formatAmount(subAmt)} (${subPct.toStringAsFixed(0)}%)',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).brightness == Brightness.dark
                                                            ? Colors.white70
                                                            : AppTheme.lightTextPrimary.withValues(alpha: 0.8),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: sortedCategoryIds.length,
                            ),
                          ),

                    // 3. Transactions Section Header
                    SliverPadding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'RECENT EXPENSES',
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

                    // 4. Expense transactions list
                    filteredExpenses.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.money_off_rounded,
                                      size: 44,
                                      color: AppTheme.secondaryText.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No expenses yet.\nTap + to add one!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppTheme.secondaryText),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final exp = filteredExpenses[index];
                                final dateStr = DateFormat('dd MMM yyyy').format(exp.date);
                                final syncIcon = exp.isDirty
                                    ? const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.warningOrange)
                                    : const Icon(Icons.done_all_rounded, size: 12, color: AppTheme.primaryLight);

                                // Find category details from database categories list
                                final matchCat = categories.firstWhere(
                                  (c) => c.id == exp.categoryId,
                                  orElse: () => ExpenseCategory(
                                    id: exp.categoryId,
                                    userId: widget.userId,
                                    name: 'Others',
                                    icon: 'category_rounded',
                                    color: '#90A4AE',
                                    subCategories: '[]',
                                    createdAt: DateTime.now(),
                                    updatedAt: DateTime.now(),
                                    isDirty: false,
                                    isDeleted: false,
                                  ),
                                );

                                final catName = matchCat.name;
                                final catColor = _getColorFromHex(matchCat.color);
                                final catIcon = _getIconFromString(matchCat.icon);
                                final subCatName = exp.subCategory;
                                final remarks = exp.remarks ?? '';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  child: InkWell(
                                    onTap: () => _openAddExpenseSheet(context, exp: exp),
                                    onLongPress: () => _confirmDeleteExpense(context, exp),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      decoration: AppTheme.glassmorphicBox(context: context),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          // Category color & icon avatar
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: catColor.withValues(alpha: 0.12),
                                            foregroundColor: catColor,
                                            child: Icon(catIcon, size: 20),
                                          ),
                                          const SizedBox(width: 14),

                                          // Category & Remarks text
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      subCatName,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: Theme.of(context).brightness == Brightness.dark
                                                            ? Colors.white
                                                            : AppTheme.lightTextPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '($catName)',
                                                      style: const TextStyle(
                                                        color: AppTheme.secondaryText,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  remarks.isNotEmpty ? remarks : 'No notes',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? AppTheme.secondaryText
                                                        : AppTheme.lightTextSecondary,
                                                    fontStyle: remarks.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Amount & Status indicator
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                AppTheme.formatAmount(exp.amount),
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.debitRed,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Text(
                                                    dateStr,
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      color: AppTheme.secondaryText,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  syncIcon,
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: filteredExpenses.length,
                            ),
                          ),
                    // Bottom margin for the FAB overlap
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error loading expenses: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (e, _) => Center(child: Text('Error loading categories: $e')),
    );
  }
}
