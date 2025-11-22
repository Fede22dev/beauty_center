import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../tabs/app_tabs.dart';
import 'custom_snackbar.dart';

enum PhoneAction { call, sms, whatsapp }

class ContactActions {
  // ------------------------------------------------------------
  // WHATSAPP HANDLER
  // ------------------------------------------------------------
  static Future<void> openWhatsApp(
    final BuildContext context,
    final String phoneNumber,
  ) async {
    final appUri = Uri.parse('whatsapp://send?phone=$phoneNumber');

    if (kIsWindows) {
      await _safeLaunch(appUri);

      await Future<void>.delayed(const Duration(milliseconds: 3000));

      if (await _safeLaunch(appUri)) return;

      if (context.mounted) {
        _showError(context, 'Impossibile aprire la chat WhatsApp');
      }

      return;
    }

    // ANDROID -> try app -> fallback web
    if (await _safeLaunch(appUri)) return;

    final webUri = Uri.parse('https://wa.me/$phoneNumber');
    if (await _safeLaunch(webUri, external: true)) return;

    if (context.mounted) {
      _showError(context, 'Impossibile aprire WhatsApp');
    }
  }

  // ------------------------------------------------------------
  // EMAIL HANDLER
  // ------------------------------------------------------------
  static Future<void> openEmail(
    final BuildContext context,
    final String email,
  ) async {
    if (kIsWindows) {
      final gmailUri = Uri.parse(
        'https://mail.google.com/mail/u/0/?'
        'to=${Uri.encodeComponent(email)}&'
        '&tf=cm',
      );

      if (await _safeLaunch(gmailUri, external: true)) return;
    }

    // Fallback mailto
    final mailtoUri = Uri.parse('mailto:$email');
    if (await _safeLaunch(mailtoUri)) return;

    if (context.mounted) {
      _showError(context, 'Impossibile aprire Gmail');
    }
  }

  // ------------------------------------------------------------
  // PHONE ACTION (call, sms, whatsapp)
  // ------------------------------------------------------------
  static Future<void> handlePhoneAction(
    final BuildContext context,
    final String phoneNumber,
    final PhoneAction action,
  ) {
    switch (action) {
      case PhoneAction.call:
        return _launchWithError(
          context,
          Uri.parse('tel:$phoneNumber'),
          'Impossibile avviare la chiamata',
        );

      case PhoneAction.sms:
        return _launchWithError(
          context,
          Uri.parse('sms:$phoneNumber'),
          'Impossibile aprire SMS',
        );

      case PhoneAction.whatsapp:
        return openWhatsApp(context, phoneNumber);
    }
  }

  // ------------------------------------------------------------
  // PHONE ACTION DIALOG
  // ------------------------------------------------------------
  static Future<void> showPhoneActionDialog(
    final BuildContext context,
    final String phoneNumber,
  ) async {
    // Windows only whatsapp
    if (kIsWindows) {
      await openWhatsApp(context, phoneNumber);
      return;
    }

    final action = await showDialog<PhoneAction>(
      context: context,
      builder: (final context) => AlertDialog(
        title: const Text('Contatta cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.call_rounded, color: Colors.green),
              title: const Text('Chiama'),
              subtitle: Text(phoneNumber),
              onTap: () => Navigator.pop(context, PhoneAction.call),
            ),
            ListTile(
              leading: const Icon(Symbols.message_rounded, color: Colors.blue),
              title: const Text('SMS'),
              subtitle: Text(phoneNumber),
              onTap: () => Navigator.pop(context, PhoneAction.sms),
            ),
            ListTile(
              leading: const Icon(
                FontAwesomeIcons.whatsapp,
                color: Colors.green,
              ),
              title: const Text('WhatsApp'),
              subtitle: Text(phoneNumber),
              onTap: () => Navigator.pop(context, PhoneAction.whatsapp),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );

    if (action != null && context.mounted) {
      await handlePhoneAction(context, phoneNumber, action);
    }
  }

  // ------------------------------------------------------------
  // SUPPORT METHODS
  // ------------------------------------------------------------
  static Future<bool> _safeLaunch(
    final Uri uri, {
    final bool external = false,
  }) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: external
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );

        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> _launchWithError(
    final BuildContext context,
    final Uri uri,
    final String errorMessage,
  ) async {
    if (await _safeLaunch(uri)) return;

    if (context.mounted) {
      _showError(context, errorMessage);
    }
  }

  static void _showError(final BuildContext context, final String msg) {
    showCustomSnackBar(
      context: context,
      message: msg,
      okColor: AppTabs.clients.color,
    );
  }
}
