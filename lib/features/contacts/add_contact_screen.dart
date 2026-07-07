import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/database/local_db.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/contact_picker.dart';

class AddContactScreen extends ConsumerStatefulWidget {
  final String userId;
  final Contact? contactToEdit;

  const AddContactScreen({super.key, required this.userId, this.contactToEdit});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.contactToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.contactToEdit!.name;
      _phoneController.text = widget.contactToEdit!.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickFromContacts() async {
    final picked = await ContactPicker.pickContact();
    if (picked == null) return;
    if (picked.name.isNotEmpty) {
      _nameController.text = picked.name;
    }
    if (picked.phone.isEmpty) {
      _phoneController.text = '';
      return;
    }
    _phoneController.text = picked.phone;

    if (!mounted) return;
    final db = ref.read(dbProvider);
    final existing = await db.getContactByPhone(widget.userId, picked.phone);
    if (existing == null) return;
    if (!mounted) return;

    if (existing.isArchived) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Contact Archived'),
            content: Text('"${existing.name}" is already saved but archived. What would you like to do?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'unarchive'),
                child: const Text('Unarchive'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'add'),
                child: const Text('Add Anyway'),
              ),
            ],
          );
        },
      );
      if (action == 'unarchive') {
        await db.unarchiveContact(existing.id);
        ref.read(syncEngineProvider).triggerSync();
        if (mounted) Navigator.pop(context);
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Already Exists'),
              content: Text('"${existing.name}" is already in your contacts.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
      _nameController.clear();
      _phoneController.clear();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final db = ref.read(dbProvider);

    if (_isEditing) {
      await db.upsertContact(widget.contactToEdit!.copyWith(
        name: _nameController.text.trim(),
        phone: Value<String?>(_phoneController.text.trim().isEmpty ? null : _phoneController.text.trim()),
        updatedAt: DateTime.now(),
        isDirty: true,
      ));
    } else {
      await db.upsertContact(Contact(
        id: const Uuid().v4(),
        userId: widget.userId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDirty: true,
        isDeleted: false,
        isArchived: false,
      ));
    }

    ref.read(syncEngineProvider).triggerSync();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Contact' : 'New Contact',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: _save,
              icon: Icon(Icons.save_outlined, color: AppTheme.primary),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
              // Name field
              Text(
                'Full Name',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Ramesh Kumar',
                  hintStyle: TextStyle(color: AppTheme.secondaryText.withValues(alpha: 0.4)),
                  prefixIcon: Icon(Icons.person_outline, size: 20),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a name';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Phone field
              Text(
                'Phone Number',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Optional',
                  hintStyle: TextStyle(color: AppTheme.secondaryText.withValues(alpha: 0.4)),
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 20),

              // From Contacts (only for new contact)
              if (!_isEditing)
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _pickFromContacts,
                    icon: const Icon(Icons.contacts_outlined, size: 18),
                    label: const Text('From Contacts'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
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
