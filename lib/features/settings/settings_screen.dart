import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/providers.dart';
import '../../core/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/delete_confirm_dialog.dart';
import '../../core/pocketbase/pocketbase_client.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _dangerExpanded = false;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  @override
  Widget build(BuildContext context) {
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
          // Profile Card
          _buildProfileCard(context, record: record, displayName: displayName, isDark: isDark),
          const SizedBox(height: 12),

          // Appearance Card
          _buildSettingsCard(
            context,
            children: [
              _buildTile(
                context,
                icon: Icons.numbers_rounded,
                title: 'Decimal Format',
                subtitle: _decimalLabel(settings.decimalFormat),
                onTap: () => _showDecimalSheet(context, ref),
              ),
              _buildTile(
                context,
                icon: Icons.dashboard_rounded,
                title: 'Default Page',
                subtitle: settings.defaultPage == DefaultPage.ledger ? 'Ledger' : 'Expense',
                onTap: () => _showDefaultPageSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Data Card
          _buildSettingsCard(
            context,
            children: [
              _buildTile(
                context,
                icon: Icons.download_rounded,
                title: 'Export as CSV',
                onTap: () => AppTheme.showSnackBar(context, 'Coming soon!'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // About Card
          _buildSettingsCard(
            context,
            children: [
              _buildTile(
                context,
                icon: Icons.description_outlined,
                title: 'Privacy Policy',
                onTap: () async {
                  final url = Uri.parse('https://ledgeo.paisamilega.in/privacy');
                  if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(height: 1, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              _buildTile(
                context,
                icon: Icons.message_rounded,
                title: 'WhatsApp Support',
                onTap: () async {
                  final url = Uri.parse('https://wa.me/919752146314');
                  if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
              _buildTile(
                context,
                icon: Icons.email_outlined,
                title: 'Email Support',
                onTap: () async {
                  final url = Uri.parse('mailto:admin@credlawn.com');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(height: 1, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              _buildTile(
                context,
                icon: Icons.info_outline_rounded,
                title: 'V ${_packageInfo?.version ?? '...'}',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Account Card
          if (!isGuest)
            _buildSettingsCard(
              context,
              children: [
                _buildTile(
                  context,
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  textColor: AppTheme.debitRed,
                  onTap: () async {
                    await ref.read(authNotifierProvider.notifier).logout();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          if (!isGuest) ...[
            const SizedBox(height: 24),
            _buildDangerZone(context),
          ],
        ],
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkCard : const Color(0xFFF7F8FA);
    final accentColor = isDark ? Colors.grey.shade500 : const Color(0xFF8E8E93);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _dangerExpanded = !_dangerExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Danger Zone',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _dangerExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(),
            secondChild: _buildDeleteAccountTile(context),
            crossFadeState: _dangerExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountTile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.grey.shade500 : const Color(0xFF8E8E93);

    return InkWell(
      onTap: () async {
        final confirmed = await DeleteConfirmDialog.show(
          context: context,
          title: 'Delete Account?',
          message: 'Your account and all associated data will be permanently deleted. You can cancel this request by logging back in within 5 days.',
          confirmLabel: 'Delete Account',
        );
        if (confirmed == true && context.mounted) {
          try {
            await PocketBaseService.deleteAccount();
          } catch (_) {}
          await PocketBaseService.signOut();
          if (context.mounted) {
            AppTheme.showSnackBar(context, 'Deletion request submitted. Log in within 5 days to cancel.');
            Navigator.pop(context);
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          children: [
            const SizedBox(width: 28),
            Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: accentColor,
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Account',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: accentColor,
              ),
            ),
          ],
        ),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? AppTheme.darkCard : Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: Icon(Icons.person_rounded, color: AppTheme.primaryLight, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
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
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? AppTheme.darkCard : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSubtitle = subtitle != null;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: textColor ?? AppTheme.primaryLight, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                    ),
                  ),
                  if (hasSubtitle)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText),
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
          ],
        ),
      ),
     );
  }
}
