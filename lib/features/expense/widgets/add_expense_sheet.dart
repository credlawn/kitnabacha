import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column, Table;
import '../../../core/database/local_db.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class AddExpenseSheet extends ConsumerStatefulWidget {
  final String userId;
  final Expense? editExpense; // Optional expense to edit

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
      
      List<String> subs = [];
      try {
        final List<dynamic> parsed = jsonDecode(_selectedCategory!.subCategories);
        subs = parsed.map((e) => e.toString()).toList();
      } catch (_) {}

      if (subs.isNotEmpty) {
        _selectedSubCategory = subs.first;
      }
    }

    // Populate for editing if editExpense is provided
    if (widget.editExpense != null) {
      final exp = widget.editExpense!;
      _amountController.text = exp.amount.toString();
      _selectedDate = exp.date;
      _remarksController.text = exp.remarks ?? '';

      final matchCat = _categories.firstWhere(
        (c) => c.id == exp.categoryId,
        orElse: () => _categories.first,
      );
      _selectedCategory = matchCat;
      
      List<String> subs = [];
      try {
        final List<dynamic> parsed = jsonDecode(matchCat.subCategories);
        subs = parsed.map((e) => e.toString()).toList();
      } catch (_) {}

      if (subs.contains(exp.subCategory)) {
        _selectedSubCategory = exp.subCategory;
      } else if (subs.isNotEmpty) {
        _selectedSubCategory = subs.first;
      } else {
        _selectedSubCategory = null;
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
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
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      AppTheme.showSnackBar(context, 'Please enter a valid amount greater than 0');
      return;
    }

    final db = ref.read(dbProvider);
    final isEdit = widget.editExpense != null;

    final exp = Expense(
      id: isEdit ? widget.editExpense!.id : const Uuid().v4(),
      userId: widget.userId,
      categoryId: _selectedCategory!.id,
      subCategory: _selectedSubCategory ?? 'General',
      amount: amount,
      remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      date: _selectedDate,
      createdAt: isEdit ? widget.editExpense!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
      isDirty: widget.userId != 'guest',
      isDeleted: false,
    );

    await db.upsertExpense(exp);
    ref.read(syncEngineProvider).triggerSync();

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (_categories.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'No Categories Configured',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Please add categories from the management screen first.',
              style: TextStyle(color: AppTheme.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    final isEdit = widget.editExpense != null;
    
    List<String> currentSubCategories = [];
    if (_selectedCategory != null) {
      try {
        final List<dynamic> parsed = jsonDecode(_selectedCategory!.subCategories);
        currentSubCategories = parsed.map((e) => e.toString()).toList();
      } catch (_) {}
    }

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
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Expense' : 'Add Expense',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount Input Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: !isEdit,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    prefixIcon: Icon(Icons.currency_rupee_rounded, size: 22),
                    hintText: '0.00',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category Selector Dropdown
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: _categories.map((cat) {
                    final catColor = _getColorFromHex(cat.color);
                    final iconName = cat.icon;
                    return DropdownMenuItem<ExpenseCategory>(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(_getIconFromString(iconName), color: catColor, size: 20),
                          const SizedBox(width: 12),
                          Text(cat.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (cat) {
                    setState(() {
                      _selectedCategory = cat;
                      
                      List<String> subs = [];
                      if (cat != null) {
                        try {
                          final List<dynamic> parsed = jsonDecode(cat.subCategories);
                          subs = parsed.map((e) => e.toString()).toList();
                        } catch (_) {}
                      }

                      if (subs.isNotEmpty) {
                        _selectedSubCategory = subs.first;
                      } else {
                        _selectedSubCategory = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Sub-category Selector Dropdown
                if (currentSubCategories.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: currentSubCategories.contains(_selectedSubCategory) ? _selectedSubCategory : null,
                    decoration: const InputDecoration(
                      labelText: 'Sub-category',
                      prefixIcon: Icon(Icons.subdirectory_arrow_right_rounded),
                    ),
                    items: currentSubCategories.map((sub) {
                      return DropdownMenuItem<String>(
                        value: sub,
                        child: Text(sub),
                      );
                    }).toList(),
                    onChanged: (sub) {
                      setState(() {
                        _selectedSubCategory = sub;
                      });
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkBorder
                            : AppTheme.lightBorder,
                      ),
                    ),
                      child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.secondaryText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No sub-categories available. Add sub-categories in Manage Categories to select here.',
                            style: TextStyle(color: AppTheme.secondaryText, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Date and Remarks row/fields
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.darkBorder
                            : AppTheme.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.secondaryText),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Date',
                                style: TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd MMM yyyy (EEEE)').format(_selectedDate),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppTheme.secondaryText),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _remarksController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Notes',
                    prefixIcon: Icon(Icons.notes_rounded),
                    hintText: 'e.g. Chai for office guests',
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isEdit ? 'Update Expense' : 'Save Expense',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
