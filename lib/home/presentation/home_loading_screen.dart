import 'dart:async';

import 'package:beauty_center/core/connectivity/connectivity_provider.dart';
import 'package:beauty_center/core/localizations/extensions/l10n_extensions.dart';
import 'package:beauty_center/core/widgets/custom_snackbar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/logging/app_logger.dart';
import 'desktop/pages/home_page_desktop.dart';
import 'mobile/pages/home_page_mobile.dart';

/// Update checker service - separates business logic from UI
class UpdateService {
  static final log = AppLogger.getLogger(name: 'UpdateService');

  static const _repoOwner = 'Fede22dev';
  static const _repoName = 'beauty_center';
  static const _apiBaseUrl = 'https://api.github.com/repos';
  static const _connectionTimeout = Duration(seconds: 5);

  // Cache current version to avoid multiple package info queries
  static String? _cachedCurrentVersion;

  /// Gets the current app version from package info
  static Future<String> getCurrentVersion() async {
    _cachedCurrentVersion ??= (await PackageInfo.fromPlatform()).version;
    return _cachedCurrentVersion!;
  }

  /// Checks for available updates on GitHub releases
  static Future<UpdateInfo> checkForUpdate() async {
    final platform = kIsWindows ? 'windows' : 'android';
    final fileExtension = platform == 'windows' ? '.exe' : '.apk';

    try {
      final currentVersion = await getCurrentVersion();
      final dio = Dio(
        BaseOptions(
          connectTimeout: _connectionTimeout,
          receiveTimeout: _connectionTimeout,
        ),
      );

      const apiUrl = '$_apiBaseUrl/$_repoOwner/$_repoName/releases/latest';
      final response = await dio.get<Map<String, dynamic>>(apiUrl);

      if (response.statusCode != 200 || response.data == null) {
        throw Exception('GitHub API returned status: ${response.statusCode}');
      }

      final data = response.data!;
      final latestVersion =
          (data['tag_name'] as String?)?.replaceFirst('v', '') ??
          currentVersion;

      // Find the correct asset for the current platform
      final assets =
          (data['assets'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [];

      final targetAsset = assets.firstWhere(
        (final asset) =>
            (asset['name'] as String?)?.toLowerCase().endsWith(fileExtension) ??
            false,
        orElse: () => <String, dynamic>{},
      );

      final downloadUrl = targetAsset.isNotEmpty
          ? targetAsset['browser_download_url'] as String?
          : null;

      final hasUpdate = _compareVersions(latestVersion, currentVersion);

      return UpdateInfo(
        hasUpdate: hasUpdate,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
      );
    } catch (e, stackTrace) {
      log.severe('Failed to check for updates', e, stackTrace);
      return UpdateInfo.noUpdate();
    }
  }

  /// Compares two semantic version strings
  /// Returns true if [latest] is newer than [current]
  static bool _compareVersions(final String latest, final String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();
      final maxLength = latestParts.length > currentParts.length
          ? latestParts.length
          : currentParts.length;

      for (var i = 0; i < maxLength; i++) {
        final latestPart = i < latestParts.length ? latestParts[i] : 0;
        final currentPart = i < currentParts.length ? currentParts[i] : 0;

        if (latestPart > currentPart) return true;
        if (latestPart < currentPart) return false;
      }

      return false;
    } catch (e, stackTrace) {
      log.warning('Version comparison failed', e, stackTrace);
      return false;
    }
  }
}

/// Update info data model
class UpdateInfo {
  const UpdateInfo({
    required this.hasUpdate,
    this.latestVersion,
    this.downloadUrl,
  });

  factory UpdateInfo.noUpdate() => const UpdateInfo(hasUpdate: false);

  factory UpdateInfo.fromJson(final Map<String, dynamic> json) => UpdateInfo(
    hasUpdate: json['hasUpdate'] as bool? ?? false,
    latestVersion: json['latestVersion'] as String?,
    downloadUrl: json['downloadUrl'] as String?,
  );

  final bool hasUpdate;
  final String? latestVersion;
  final String? downloadUrl;

  bool get canDownload => hasUpdate && downloadUrl != null;
}

/// Home loading screen widget
class HomeLoadingScreen extends ConsumerStatefulWidget {
  const HomeLoadingScreen({super.key});

  @override
  ConsumerState<HomeLoadingScreen> createState() => _HomeLoadingScreenState();
}

class _HomeLoadingScreenState extends ConsumerState<HomeLoadingScreen> {
  static final _log = AppLogger.getLogger(name: 'HomeLoadingScreen');

  var _showLoading = false;

  @override
  void initState() {
    super.initState();

    Future.microtask(_initialize);
  }

  /// Initializes the screen and checks for updates if online
  Future<void> _initialize() async {
    try {
      final isOffline = ref.read(isConnectionUnusableProvider);

      if (!mounted) return;

      if (isOffline) {
        _navigateToHome();
      } else {
        setState(() => _showLoading = true);
        await _performUpdateCheck();
      }
    } catch (e, stackTrace) {
      _log.severe('Initialization failed', e, stackTrace);
      if (mounted) {
        _showErrorMessage(e.toString());
        _navigateToHome();
      }
    }
  }

  /// Checks for app updates and shows dialog if available
  Future<void> _performUpdateCheck() async {
    try {
      final update = await UpdateService.checkForUpdate();

      if (!mounted) return;

      if (update.canDownload) {
        final currentVersion = await UpdateService.getCurrentVersion();
        await _showUpdateDialog(
          currentVersion: currentVersion,
          newVersion: update.latestVersion!,
          downloadUrl: update.downloadUrl!,
        );
      }
    } catch (e, stackTrace) {
      _log.warning('Update check failed', e, stackTrace);
      _showErrorMessage(e.toString());
    } finally {
      if (mounted) _navigateToHome();
    }
  }

  /// Shows error message via snackbar
  void _showErrorMessage(final String message) {
    if (mounted) {
      showCustomSnackBar(context: context, message: message);
    }
  }

  /// Displays update dialog with download option
  Future<void> _showUpdateDialog({
    required final String currentVersion,
    required final String newVersion,
    required final String downloadUrl,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (final context) => AlertDialog(
        title: Text(context.l10n.updateAvailable),
        content: Text('$currentVersion -> $newVersion'),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Symbols.download),
            label: Text(context.l10n.update),
            onPressed: () async {
              Navigator.of(context).pop();
              await _launchDownloadUrl(downloadUrl);
            },
          ),
          TextButton.icon(
            icon: const Icon(Symbols.close),
            label: Text(context.l10n.ignore),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Launches the download URL in external browser
  Future<void> _launchDownloadUrl(final String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not launch URL: $url');
      }
    } catch (e, stackTrace) {
      _log.warning('Failed to launch URL', e, stackTrace);
      if (mounted) {
        _showErrorMessage(e.toString());
      }
    }
  }

  /// Navigates to the appropriate home page based on platform
  void _navigateToHome() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            kIsWindows ? const HomePageDesktop() : const HomePageMobile(),
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    if (!_showLoading) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: kIsWindows ? 16 : 16.h),
            Text(context.l10n.checkUpdate),
          ],
        ),
      ),
    );
  }
}
