import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInfo {
  final String version;
  final int build;
  final String apkUrl;
  final bool mandatory;
  final String? changelog;
  final String? sha256;

  UpdateInfo({
    required this.version,
    required this.build,
    required this.apkUrl,
    required this.mandatory,
    this.changelog,
    this.sha256,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      build: json['build'] as int,
      apkUrl: json['apk_url'] as String,
      mandatory: json['mandatory'] as bool? ?? false,
      changelog: json['changelog'] as String?,
      sha256: json['sha256'] as String?,
    );
  }
}

class UpdateService {
  // Hosted on Supabase Storage
  static const _versionUrl =
      'https://tikfrwuiffzjgxlqvxde.supabase.co/storage/v1/object/public/apk/version.json';
  static const _keyLastOfferedVersion = 'update_last_offered_version';

  static int _compareVersions(String a, String b) {
    final pa = a.split('.').map(int.parse).toList();
    final pb = b.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  static Future<UpdateInfo?> _fetchUpdateInfo() async {
    try {
      final res = await http.get(Uri.parse(_versionUrl));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return UpdateInfo.fromJson(data);
    } catch (e) {
      debugPrint('[UpdateService] Error fetching version.json: $e');
      return null;
    }
  }

  static Future<bool> _isUpdateAvailable(UpdateInfo info) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    final versionCmp = _compareVersions(info.version, currentVersion);
    if (versionCmp > 0) return true;
    if (versionCmp == 0 && info.build > currentBuild) return true;
    return false;
  }

  static Future<void> showUpdateDialogIfNeeded(BuildContext context) async {
    final info = await _fetchUpdateInfo();
    if (info == null) return;

    final hasUpdate = await _isUpdateAvailable(info);
    if (!hasUpdate) return;

    // Ne pas réafficher pour la même version déjà proposée (après MAJ ou "Plus tard")
    final offeredKey = '${info.version}+${info.build}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyLastOfferedVersion) == offeredKey) return;

    await _showUpdateDialog(context, info, offeredKey);
  }

  /// Check for updates and show dialog or feedback (e.g. from Settings).
  static Future<void> checkForUpdatesWithFeedback(BuildContext context) async {
    final info = await _fetchUpdateInfo();
    if (info == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de vérifier les mises à jour (réseau ou fichier version.json manquant)',
            ),
          ),
        );
      }
      return;
    }
    final hasUpdate = await _isUpdateAvailable(info);
    if (!hasUpdate) {
      if (context.mounted) {
        final pkg = await PackageInfo.fromPlatform();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vous avez déjà la dernière version (${pkg.version}+${pkg.buildNumber})',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }
    await _showUpdateDialog(context, info, '${info.version}+${info.build}');
  }

  static Future<void> _showUpdateDialog(
    BuildContext context,
    UpdateInfo info,
    String offeredKey,
  ) async {
    final pkg = await PackageInfo.fromPlatform();

    final sb = StringBuffer()
      ..writeln('Version actuelle : ${pkg.version}+${pkg.buildNumber}')
      ..writeln('Nouvelle version : ${info.version}+${info.build}')
      ..writeln();

    if (info.changelog != null && info.changelog!.isNotEmpty) {
      sb.writeln('Notes de version :');
      sb.writeln(info.changelog);
    }

    final actions = <Widget>[
      // Toujours proposer "Plus tard" / "Fermer" pour ne pas bloquer l'entrée
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(info.mandatory ? 'Fermer' : 'Plus tard'),
      ),
      TextButton(
        onPressed: () async {
          Navigator.of(context).pop();
          await _downloadAndInstallApk(context, info.apkUrl);
        },
        child: const Text('Mettre à jour'),
      ),
    ];

    // ignore: use_build_context_synchronously
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(
          info.mandatory ? 'Mise à jour obligatoire' : 'Nouvelle version disponible',
        ),
        content: Text(sb.toString()),
        actions: actions,
      ),
    );

    // Après toute fermeture (bouton, tap extérieur, retour) : ne plus réafficher cette version
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastOfferedVersion, offeredKey);
  }

  static Future<void> _downloadAndInstallApk(
    BuildContext context,
    String url,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Téléchargement de la mise à jour...')),
      );

      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur téléchargement APK (code ${res.statusCode})',
            ),
          ),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/bekkapp_update.apk';
      final file = File(filePath);
      await file.writeAsBytes(res.bodyBytes);

      await OpenFilex.open(filePath);
    } catch (e) {
      debugPrint('[UpdateService] Error during update: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $e'),
          ),
        );
      }
    }
  }
}

