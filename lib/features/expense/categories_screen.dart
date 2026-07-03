import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/local_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  final String userId;
  const CategoriesScreen({super.key, required this.userId});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
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

  final List<String> _availableColors = [
    '#FF9F43', // Orange
    '#FF5252', // Red
    '#536DFE', // Indigo
    '#9C27B0', // Purple
    '#E040FB', // Light Purple
    '#00E676', // Green
    '#00B0FF', // Light Blue
    '#FFD700', // Gold
    '#FF69B4', // Hot Pink
    '#4DB6AC', // Teal
    '#90A4AE', // Slate Grey
  ];

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

  void _showAddCategorySheet() {
    final nameController = TextEditingController();
    String selectedIconKey = _availableIcons.keys.first;
    String selectedColorHex = _availableColors.first;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                            'Add New Category',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Category Name',
                          hintText: 'e.g. Education, Travel',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a category name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Select Icon',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondaryText),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 56,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _availableIcons.length,
                          itemBuilder: (context, idx) {
                            final key = _availableIcons.keys.elementAt(idx);
                            final icon = _availableIcons[key]!;
                            final isSelected = selectedIconKey == key;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: InkWell(
                                onTap: () => setModalState(() => selectedIconKey = key),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppTheme.primary.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.primary : Colors.grey.withValues(alpha: 0.3),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.secondaryText),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Select Color',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondaryText),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _availableColors.length,
                          itemBuilder: (context, idx) {
                            final colorHex = _availableColors[idx];
                            final color = _getColorFromHex(colorHex);
                            final isSelected = selectedColorHex == colorHex;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                onTap: () => setModalState(() => selectedColorHex = colorHex),
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final name = nameController.text.trim();
                          final db = ref.read(dbProvider);

                          await db.upsertExpenseCategory(ExpenseCategory(
                            id: const Uuid().v4(),
                            userId: widget.userId,
                            name: name,
                            icon: selectedIconKey,
                            color: selectedColorHex,
                            subCategories: '[]',
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                            isDirty: widget.userId != 'guest',
                            isDeleted: false,
                          ));

                          ref.read(syncEngineProvider).triggerSync();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Add Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddSubCategoryDialog(ExpenseCategory category) {
    final subController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text('Add Sub-category to ${category.name}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: subController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Sub-category Name',
                hintText: 'e.g. Milk, Petrol, Gym',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.secondaryText)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final subName = subController.text.trim();
                final db = ref.read(dbProvider);
                
                List<String> currentSubs = [];
                try {
                  final List<dynamic> parsed = jsonDecode(category.subCategories);
                  currentSubs = parsed.map((e) => e.toString()).toList();
                } catch (_) {}

                if (!currentSubs.contains(subName)) {
                  currentSubs.add(subName);
                  
                  await db.upsertExpenseCategory(category.copyWith(
                    subCategories: jsonEncode(currentSubs),
                    updatedAt: DateTime.now(),
                    isDirty: widget.userId != 'guest',
                  ));
                  
                  ref.read(syncEngineProvider).triggerSync();
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _deleteCategory(ExpenseCategory category) async {
    final expenses = await ref.read(dbProvider).getActiveExpensesForCategory(category.id);
    if (expenses > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete — $expenses expense(s) use this category. Remove them first.'),
          backgroundColor: AppTheme.debitRed,
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.debitRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(dbProvider);
      await db.softDeleteExpenseCategory(category.id);
      ref.read(syncEngineProvider).triggerSync();
    }
  }

  void _deleteSubCategory(ExpenseCategory category, String subName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Delete Sub-category?'),
        content: Text('Are you sure you want to delete sub-category "$subName" from "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.debitRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(dbProvider);
      List<String> currentSubs = [];
      try {
        final List<dynamic> parsed = jsonDecode(category.subCategories);
        currentSubs = parsed.map((e) => e.toString()).toList();
      } catch (_) {}

      currentSubs.remove(subName);

      await db.upsertExpenseCategory(category.copyWith(
        subCategories: jsonEncode(currentSubs),
        updatedAt: DateTime.now(),
        isDirty: widget.userId != 'guest',
      ));
      
      ref.read(syncEngineProvider).triggerSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(expenseCategoriesStreamProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
      ),
      body: categoriesState.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('No categories found. Tap (+) to add.', style: TextStyle(color: AppTheme.secondaryText)));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: categories.length,
            itemBuilder: (context, idx) {
              final cat = categories[idx];
              final catColor = _getColorFromHex(cat.color);
              final catIcon = _getIconFromString(cat.icon);
              
              List<String> subs = [];
              try {
                final List<dynamic> parsed = jsonDecode(cat.subCategories);
                subs = parsed.map((e) => e.toString()).toList();
              } catch (_) {}

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: AppTheme.glassmorphicBox(context: context),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: catColor.withValues(alpha: 0.12),
                    foregroundColor: catColor,
                    child: Icon(catIcon),
                  ),
                  title: Text(
                    cat.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${subs.length} sub-categories',
                    style: const TextStyle(color: AppTheme.secondaryText, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 22),
                        onPressed: () => _showAddSubCategoryDialog(cat),
                        tooltip: 'Add Sub-category',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.debitRed, size: 22),
                        onPressed: () => _deleteCategory(cat),
                        tooltip: 'Delete Category',
                      ),
                    ],
                  ),
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  backgroundColor: Colors.transparent,
                  collapsedBackgroundColor: Colors.transparent,
                  childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
                  children: [
                    if (subs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No sub-categories. Tap (+) to add.',
                          style: TextStyle(color: AppTheme.secondaryText, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: subs.map((sub) {
                          return Chip(
                            label: Text(sub, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkBg
                                : AppTheme.lightBg,
                            side: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.debitRed),
                            onDeleted: () => _deleteSubCategory(cat, sub),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error loading categories: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategorySheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
