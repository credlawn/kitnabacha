import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pocketbase/pocketbase_client.dart';

class UpdateChecker {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> check() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        try {
          if (info.immediateUpdateAllowed) {
            await InAppUpdate.performImmediateUpdate();
          } else {
            await InAppUpdate.startFlexibleUpdate();
            InAppUpdate.completeFlexibleUpdate();
          }
          return;
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final pkg = await PackageInfo.fromPlatform();
      final currentVersion = pkg.version;

      final records = await PocketBaseService.client
          .collection('app_config')
          .getList(page: 1, perPage: 1);
      if (records.items.isEmpty) return;
      final record = records.items.first;

      final latestVersion = record.getStringValue('latest_version');
      final mandatory = record.getBoolValue('update_mandatory');
      final updateUrl = record.getStringValue('update_url');

      if (_compareVersions(currentVersion, latestVersion) >= 0) return;

      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      if (!ctx.mounted) return;

      await showDialog(
        context: ctx,
        barrierDismissible: !mandatory,
        builder: (ctx) => PopScope(
          canPop: !mandatory,
          child: AlertDialog(
            title: Text(mandatory ? 'Update Required' : 'Update Available'),
            content: Text(
              mandatory
                  ? 'A new version ($latestVersion) is required. Please update to continue.'
                  : 'A new version ($latestVersion) is available. Update now?',
            ),
            actions: [
              if (!mandatory)
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Later'),
                ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final uri = Uri.tryParse(updateUrl);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}

  }

  static int _compareVersions(String a, String b) {
    final pa = a.split('.').map(int.parse).toList();
    final pb = b.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }
}
