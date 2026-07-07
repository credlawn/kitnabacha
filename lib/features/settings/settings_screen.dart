import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/providers.dart';
import '../../core/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/delete_confirm_dialog.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final record = authState.value;
    final isGuest = record == null;
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName = record == null
        ? 'Guest User'
        : record.get<String>('name').isNotEmpty == true
            ? record.get<String>('name')
            : record.get<String>('email');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(context, record: record, displayName: displayName, isDark: isDark),
          const SizedBox(height: 20),
          _buildSectionHeader(context, 'APPEARANCE'),
          const SizedBox(height: 8),
          _buildSettingTile(
            context,
            icon: Icons.numbers_rounded,
            title: 'Decimal Format',
            subtitle: _decimalLabel(settings.decimalFormat),
            onTap: () => _showDecimalSheet(context, ref),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(context, 'PREFERENCES'),
          const SizedBox(height: 8),
          _buildSettingTile(
            context,
            icon: Icons.dashboard_rounded,
            title: 'Default Page',
            subtitle: settings.defaultPage == DefaultPage.ledger ? 'Ledger' : 'Expense',
            onTap: () => _showDefaultPageSheet(context, ref),
          ),
          const Divider(height: 1),
          _buildSettingTile(
            context,
            icon: Icons.currency_rupee_rounded,
            title: 'Currency',
            subtitle: 'Indian Rupee (₹)',
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(context, 'DATA'),
          const SizedBox(height: 8),
          _buildSettingTile(
            context,
            icon: Icons.download_rounded,
            title: 'Export as CSV',
            onTap: () {
              AppTheme.showSnackBar(context, 'Coming soon!');
            },
          ),
          const Divider(height: 1),
          _buildSettingTile(
            context,
            icon: Icons.delete_outline_rounded,
            title: 'Clear All Data',
            textColor: AppTheme.debitRed,
            onTap: () async {
              final confirmed = await DeleteConfirmDialog.show(
                context: context,
                title: 'Clear All Data?',
                message: 'This will permanently delete all your contacts, transactions, and expenses. This action cannot be undone.',
                confirmLabel: 'Clear All',
              );
              if (confirmed == true && context.mounted) {
                AppTheme.showSnackBar(context, 'Data cleared successfully');
              }
            },
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(context, 'ABOUT'),
          const SizedBox(height: 8),
          _buildSettingTile(
            context,
            icon: Icons.info_outline_rounded,
            title: 'Version',
            subtitle: '1.0.0',
          ),
          const Divider(height: 1),
          if (!isGuest)
            _buildSettingTile(
              context,
              icon: Icons.logout_rounded,
              title: 'Sign Out',
              textColor: AppTheme.debitRed,
              onTap: () {
                ref.read(authNotifierProvider.notifier).logout();
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  String _decimalLabel(DecimalFormat fmt) {
    switch (fmt) {
      case DecimalFormat.none:
        return 'No Decimal (e.g. 100)';
      case DecimalFormat.one:
        return '1 Decimal Place (e.g. 100.5)';
      case DecimalFormat.two:
        return '2 Decimal Places (e.g. 100.50)';
    }
  }

  void _showDecimalSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(settingsProvider).decimalFormat;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Decimal Format',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _optionTile(ctx, 'No Decimal (e.g. 100)', DecimalFormat.none, current, Icons.looks_one_rounded, ref),
              _optionTile(ctx, '1 Decimal Place (e.g. 100.5)', DecimalFormat.one, current, Icons.looks_two_rounded, ref),
              _optionTile(ctx, '2 Decimal Places (e.g. 100.50)', DecimalFormat.two, current, Icons.looks_3_rounded, ref),
            ],
          ),
        );
      },
    );
  }

  void _showDefaultPageSheet(BuildContext context, WidgetRef ref) {
    final current = ref.read(settingsProvider).defaultPage;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Default Page',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _optionTile(ctx, 'Ledger', DefaultPage.ledger, current, Icons.menu_book_rounded, ref),
              _optionTile(ctx, 'Expense', DefaultPage.expense, current, Icons.account_balance_wallet_rounded, ref),
            ],
          ),
        );
      },
    );
  }

  Widget _optionTile(BuildContext context, String label, dynamic value, dynamic current, IconData icon, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = value == current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          if (value is DecimalFormat) ref.read(settingsProvider.notifier).setDecimalFormat(value);
          if (value is DefaultPage) ref.read(settingsProvider.notifier).setDefaultPage(value);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.1)
                : (isDark ? AppTheme.darkCard : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isSelected ? AppTheme.primary : AppTheme.secondaryText),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppTheme.primary
                        : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_rounded, size: 20, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, {required RecordModel? record, required String displayName, required bool isDark}) {
    final isGuest = record == null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: AppTheme.glassmorphicBox(context: context),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: Icon(
              Icons.person_rounded,
              color: AppTheme.primaryLight,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      isGuest ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                      size: 13,
                      color: isGuest ? AppTheme.warningOrange : AppTheme.creditGreen,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isGuest ? 'No Backup' : 'Data is Safe',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isGuest ? AppTheme.warningOrange : AppTheme.creditGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isGuest)
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Backup Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkTextSecondary
            : AppTheme.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? AppTheme.primaryLight, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: textColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.lightTextPrimary),
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText))
          : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }
}
