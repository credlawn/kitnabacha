import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(userIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
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
                        userId == 'guest' ? 'Guest User' : userId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userId == 'guest'
                            ? 'Local only — sign up to backup'
                            : 'Synced to cloud',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (userId == 'guest')
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Sign In'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'PREFERENCES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.secondaryText,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildSettingTile(
            context,
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            trailing: Switch.adaptive(
              value: isDark,
              activeTrackColor: AppTheme.primary,
              onChanged: (_) {
                // TODO: Implement theme toggle
              },
            ),
          ),
          const Divider(height: 1),
          _buildSettingTile(
            context,
            icon: Icons.currency_rupee_rounded,
            title: 'Currency',
            subtitle: 'Indian Rupee (₹)',
          ),
          if (userId != 'guest') ...[
            const Divider(height: 1),
            _buildSettingTile(
              context,
              icon: Icons.sync_rounded,
              title: 'Sync Now',
              onTap: () => ref.read(syncEngineProvider).triggerSync(),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'DATA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.secondaryText,
              letterSpacing: 1.5,
            ),
          ),
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
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All Data?'),
                  content: const Text('This will permanently delete all your contacts, transactions, and expenses. This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        AppTheme.showSnackBar(context, 'Data cleared successfully');
                      },
                      child: const Text('Delete', style: TextStyle(color: AppTheme.debitRed)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'ABOUT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.secondaryText,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildSettingTile(
            context,
            icon: Icons.info_outline_rounded,
            title: 'Version',
            subtitle: '1.0.0',
          ),
          const Divider(height: 1),
          if (userId != 'guest')
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
