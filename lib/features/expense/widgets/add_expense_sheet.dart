import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column, Table;
import '../../../core/database/local_db.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/delete_confirm_dialog.dart';
import '../categories_screen.dart';

class AddExpenseSheet extends ConsumerStatefulWidget {
  final String userId;
  final Expense? editExpense;

  const AddExpenseSheet({
    super.key,
    required this.userId,
    this.editExpense,
  });

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  List<ExpenseCategory> _categories = [];
  ExpenseCategory? _selectedCategory;
  String? _selectedSubCategory;
  bool _isLoading = true;

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
    _loadCategoriesAndInit();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.editExpense != null;

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

  Future<void> _loadCategoriesAndInit() async {
    final db = ref.read(dbProvider);
    _categories = await (db.select(db.expenseCategories)
          ..where((t) => t.userId.equals(widget.userId) & t.isDeleted.equals(false)))
        .get();

    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.first;
      final subs = _getSubs(_selectedCategory!);
      if (subs.isNotEmpty) {
        _selectedSubCategory = subs.first;
      }
    }

    if (_isEdit) {
      final exp = widget.editExpense!;
      _amountController.text = exp.amount.toString();
      _selectedDate = exp.date;
      _remarksController.text = exp.remarks ?? '';

      final matchCat = _categories.firstWhere(
        (c) => c.id == exp.categoryId,
        orElse: () => _categories.first,
      );
      _selectedCategory = matchCat;

      final subs = _getSubs(matchCat);
      if (subs.contains(exp.subCategory)) {
        _selectedSubCategory = exp.subCategory;
      } else if (subs.isNotEmpty) {
        _selectedSubCategory = subs.first;
      } else {
        _selectedSubCategory = null;
      }
    }

    setState(() => _isLoading = false);
  }

  List<String> _getSubs(ExpenseCategory cat) {
    try {
      final List<dynamic> parsed = jsonDecode(cat.subCategories);
      return parsed.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: isDark ? AppTheme.darkCard : Colors.white,
              onSurface: isDark ? Colors.white : AppTheme.lightTextPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      AppTheme.showSnackBar(context, 'Amount must be greater than 0');
      return;
    }

    final db = ref.read(dbProvider);

    final exp = Expense(
      id: _isEdit ? widget.editExpense!.id : const Uuid().v4(),
      userId: widget.userId,
      categoryId: _selectedCategory!.id,
      subCategory: _selectedSubCategory ?? 'General',
      amount: amount,
      remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      date: _selectedDate,
      createdAt: _isEdit ? widget.editExpense!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
      isDirty: widget.userId != 'guest',
      isDeleted: false,
    );

    await db.upsertExpense(exp);
    ref.read(syncEngineProvider).triggerSync();

    if (mounted) Navigator.pop(context, true);
  }

  void _deleteExpense() async {
    final confirmed = await DeleteConfirmDialog.show(
      context: context,
      title: 'Delete Expense?',
      message: 'Are you sure you want to delete this expense of ${AppTheme.formatAmount(widget.editExpense!.amount)}?',
    );
    if (confirmed == true) {
      final db = ref.read(dbProvider);
      await db.softDeleteExpense(widget.editExpense!.id);
      ref.read(syncEngineProvider).triggerSync();
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        appBar: AppBar(title: const Text('Expense', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_categories.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        appBar: AppBar(
          title: const Text('Expense', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.category_outlined, size: 48, color: AppTheme.secondaryText),
                const SizedBox(height: 16),
                const Text(
                  'No Categories Found',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add categories from the expense dashboard first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.secondaryText),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoriesScreen(userId: widget.userId),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Manage Categories'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentSubs = _getSubs(_selectedCategory!);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Expense' : 'New Expense',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: false,
        actions: [
          if (_isEdit)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                onPressed: _deleteExpense,
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.debitRed),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.debitRed.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: _saveExpense,
              icon: Icon(Icons.save_outlined, color: AppTheme.primary),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Amount
              Text(
                'Amount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: !_isEdit,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '₹ 0.00',
                  hintStyle: TextStyle(color: AppTheme.secondaryText.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkCard : AppTheme.lightBorder.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter an amount';
                  if (double.tryParse(value) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Category
              Text(
                'Category',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppTheme.darkCard : AppTheme.lightBorder.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: _categories.map((cat) {
                  final catColor = _getColorFromHex(cat.color);
                  return DropdownMenuItem<ExpenseCategory>(
                    value: cat,
                    child: Row(
                      children: [
                        Icon(_getIconFromString(cat.icon), color: catColor, size: 20),
                        const SizedBox(width: 12),
                        Text(cat.name, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (cat) {
                  setState(() {
                    _selectedCategory = cat;
                    final subs = cat != null ? _getSubs(cat) : [];
                    _selectedSubCategory = subs.isNotEmpty ? subs.first : null;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Sub-category
              if (currentSubs.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sub-category',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: currentSubs.contains(_selectedSubCategory) ? _selectedSubCategory : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppTheme.darkCard : AppTheme.lightBorder.withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      items: currentSubs.map((sub) {
                        return DropdownMenuItem<String>(
                          value: sub,
                          child: Text(sub, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary)),
                        );
                      }).toList(),
                      onChanged: (sub) => setState(() => _selectedSubCategory = sub),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              // Date
              Text(
                'Date',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.lightBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 20, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.secondaryText),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Remarks
              Text(
                'Remarks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _remarksController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Optional',
                  hintStyle: TextStyle(color: AppTheme.secondaryText.withValues(alpha: 0.4)),
                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkCard : AppTheme.lightBorder.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.primary, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
