import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/database/local_db.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/delete_confirm_dialog.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  final Contact contact;
  final String userId;
  final bool isOutflow;
  final double currentBalance;
  final TransactionModel? transactionToEdit;

  const AddTransactionSheet({
    super.key,
    required this.contact,
    required this.userId,
    required this.isOutflow,
    required this.currentBalance,
    this.transactionToEdit,
  });

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      _amountController.text = widget.transactionToEdit!.amount.toString();
      _descController.text = widget.transactionToEdit!.description ?? '';
      _selectedDate = widget.transactionToEdit!.date;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppTheme.primary,
                    onPrimary: Colors.white,
                    surface: AppTheme.darkCard,
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: AppTheme.primary,
                    onPrimary: Colors.white,
                    surface: AppTheme.lightCard,
                    onSurface: AppTheme.lightTextPrimary,
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) return;

    final db = ref.read(dbProvider);
    TransactionModel transaction;

    if (widget.transactionToEdit != null) {
      transaction = widget.transactionToEdit!.copyWith(
        amount: amount,
        description: Value(_descController.text.trim().isEmpty ? null : _descController.text.trim()),
        date: _selectedDate,
        updatedAt: DateTime.now(),
        isDirty: true,
      );
    } else {
      String resolvedType;
      if (widget.isOutflow) {
        if (widget.currentBalance < 0) {
          resolvedType = 'pay';
        } else {
          resolvedType = 'give';
        }
      } else {
        if (widget.currentBalance > 0) {
          resolvedType = 'receive';
        } else {
          resolvedType = 'take';
        }
      }

      transaction = TransactionModel(
        id: const Uuid().v4(),
        contactId: widget.contact.id,
        userId: widget.userId,
        amount: amount,
        type: resolvedType,
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        date: _selectedDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDirty: true,
        isDeleted: false,
      );
    }

    await db.upsertTransaction(transaction);
    await db.upsertContact(widget.contact.copyWith(
      updatedAt: DateTime.now(),
      isDirty: true,
    ));
    ref.read(syncEngineProvider).triggerSync();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final txn = widget.transactionToEdit;
    if (txn == null) return;

    final confirmed = await DeleteConfirmDialog.show(
      context: context,
      title: 'Delete Entry',
      message: 'Remove this ${txn.type} entry of ${AppTheme.formatAmount(txn.amount)}?',
    );

    if (confirmed != true) return;

    final db = ref.read(dbProvider);
    await db.upsertTransaction(txn.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now(),
      isDirty: true,
    ));
    await db.upsertContact(widget.contact.copyWith(
      updatedAt: DateTime.now(),
      isDirty: true,
    ));
    ref.read(syncEngineProvider).triggerSync();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transactionToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionColor = widget.isOutflow ? AppTheme.debitRed : AppTheme.creditGreen;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Entry' : (widget.isOutflow ? 'Paid' : 'Received'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: false,
        actions: [
          if (isEdit)
            IconButton(
              onPressed: _delete,
              icon: Icon(Icons.delete_outline_rounded, color: AppTheme.secondaryText),
              tooltip: 'Delete',
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _save,
              icon: Icon(
                Icons.save_outlined,
                color: actionColor,
              ),
              tooltip: isEdit ? 'Save' : 'Add',
              style: IconButton.styleFrom(
                backgroundColor: actionColor.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Contact info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      foregroundColor: AppTheme.primary,
                      child: Text(
                        widget.contact.name.trim().isNotEmpty
                            ? widget.contact.name.trim().substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.contact.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: actionColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.isOutflow ? 'Paid' : 'Received',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: actionColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                autofocus: !isEdit,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '₹ 0.00',
                  hintStyle: TextStyle(
                    color: AppTheme.secondaryText.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.darkCard
                      : AppTheme.lightBorder.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: actionColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description
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
                controller: _descController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Chai, Udhaar, online transfer',
                  hintStyle: TextStyle(
                    color: AppTheme.secondaryText.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.darkCard
                      : AppTheme.lightBorder.withValues(alpha: 0.3),
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please add a remark';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

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
                    color: isDark
                        ? AppTheme.darkCard
                        : AppTheme.lightBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
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
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppTheme.secondaryText,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
