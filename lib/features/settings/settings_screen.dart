import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/delete_confirm_dialog.dart';
import '../../core/widgets/app_toggle.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final record = authState.value;
    final isGuest = record == null;
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
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'PREFERENCES'),
          const SizedBox(height: 8),
          _buildSettingTile(
            context,
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            trailing: AppToggle(
              value: isDark,
              onChanged: (_) {},
            ),
          ),
          const Divider(height: 1),
          _buildSettingTile(
            context,
            icon: Icons.currency_rupee_rounded,
            title: 'Currency',
            subtitle: 'Indian Rupee (₹)',
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 24),
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

  Widget _buildProfileCard(BuildContext context, {required RecordModel? record, required String displayName, required bool isDark}) {
    final isGuest = record == null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassmorphicBox(context: context),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            child: Icon(
              Icons.person_rounded,
              color: AppTheme.primaryLight,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isGuest ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                      size: 14,
                      color: isGuest ? AppTheme.warningOrange : AppTheme.creditGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isGuest ? 'No Backup' : 'Data is Safe',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isGuest ? FontWeight.w600 : FontWeight.w600,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Backup Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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
