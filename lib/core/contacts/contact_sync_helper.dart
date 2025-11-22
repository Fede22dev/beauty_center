import 'dart:async';

import 'package:beauty_center/core/contacts/widgets/contact_sync_dialog.dart';
import 'package:beauty_center/core/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../../core/logging/app_logger.dart';
import '../database/app_database.dart';
import 'models/contact_change_model.dart';
import 'services/contact_service.dart';

/// Coordinator class to sync client data with device contacts.
/// Uses ContactService for logic and ContactSyncDialogs for UI.
class ContactSyncHelper {
  ContactSyncHelper._();

  static final _log = AppLogger.getLogger(name: 'ContactSyncHelper');

  static var _isInteractionActive = false;

  // ===========================================================================
  // BATCH SYNC
  // ===========================================================================

  static Future<void> syncAllPersonsToContacts(
    final BuildContext context,
    final List<Map<String, dynamic>> personsData,
  ) async {
    if (personsData.isEmpty || _isInteractionActive) return;

    final uiContext = _getSafeUiContext(context);
    if (uiContext == null) {
      _log.warning('Skipping contact sync: Context not available');
      return;
    }

    // 1. Permissions
    if (!await ContactService.requestPermission()) return;

    try {
      _isInteractionActive = true;

      // 2. Show Loading
      if (uiContext.mounted) _showLoading(uiContext);

      // 3. Fetch & Index (Heavy lifting)
      final deviceContacts = await ContactService.getAllContacts();

      final deviceMap = <String, Contact>{};
      for (final contact in deviceContacts) {
        for (final phone in contact.phones) {
          final norm = ContactService.normalizePhone(phone.number);
          if (norm.isNotEmpty) deviceMap[norm] = contact;
        }
      }

      // 4. Calculate Diff
      final pendingChanges = <PendingContactChange>[];

      for (final person in personsData) {
        final fName = person['first_name'] as String? ?? '';
        final lName = person['last_name'] as String? ?? '';
        final rawPhone = person['phone_number'] as String? ?? '';
        final email = person['email'] as String?;

        final normPhone = ContactService.normalizePhone(rawPhone);
        if (normPhone.isEmpty) continue;

        final existing = deviceMap[normPhone];

        if (existing == null) {
          pendingChanges.add(
            PendingContactChange(
              firstName: fName,
              lastName: lName,
              phone: rawPhone,
              email: email,
              type: ContactChangeType.create,
            ),
          );
        } else if (ContactService.hasChanges(
          existing: existing,
          newFirst: fName,
          newLast: lName,
          newPhone: rawPhone,
          newEmail: email,
        )) {
          pendingChanges.add(
            PendingContactChange(
              firstName: fName,
              lastName: lName,
              phone: rawPhone,
              email: email,
              type: ContactChangeType.update,
              existingContact: existing,
            ),
          );
        }
      }

      // Hide Loading
      if (uiContext.mounted) Navigator.of(uiContext).pop();

      // 5. Handle Results
      if (pendingChanges.isEmpty) {
        if (uiContext.mounted) {
          showCustomSnackBar(
            context: context,
            message: 'Contatti già sincronizzati.',
          );
        }
        return;
      }

      // 6. Show UI
      if (!uiContext.mounted) return;

      final selectedChanges = await showDialog<List<PendingContactChange>>(
        context: uiContext,
        builder: (final ctx) => BatchSyncDialog(changes: pendingChanges),
      );

      if (selectedChanges == null || selectedChanges.isEmpty) return;

      // 7. Apply Changes
      var created = 0;
      var updated = 0;

      for (final change in selectedChanges) {
        try {
          if (change.type == ContactChangeType.create) {
            await ContactService.createContact(
              firstName: change.firstName,
              lastName: change.lastName,
              phone: change.phone,
              email: change.email,
            );
            created++;
          } else if (change.type == ContactChangeType.update &&
              change.existingContact != null) {
            await ContactService.updateContact(
              contact: change.existingContact!,
              firstName: change.firstName,
              lastName: change.lastName,
              phone: change.phone,
              email: change.email,
            );
            updated++;
          }
        } catch (e) {
          if (uiContext.mounted) {
            showCustomSnackBar(
              context: context,
              message: 'Errore sync contatti: ${change.phone}',
              type: SnackBarType.error,
            );
          }
          _log.warning('Failed to sync item: ${change.phone}', e);
        }
      }

      if (created > 0 || updated > 0) {
        if (uiContext.mounted) {
          showCustomSnackBar(
            context: context,
            message: 'Sync completato: $created nuovi, $updated aggiornati.',
            type: SnackBarType.success,
          );
        }
      }
    } catch (e, s) {
      _log.severe('Batch sync error', e, s);
      // Ensure loading is closed
      if (uiContext.mounted && Navigator.canPop(uiContext)) {
        Navigator.of(uiContext).pop();
      }
      if (uiContext.mounted) {
        showCustomSnackBar(
          context: context,
          message: 'Errore sync contatti.',
          type: SnackBarType.error,
        );
      }
    } finally {
      _isInteractionActive = false;
    }
  }

  // ===========================================================================
  // SINGLE SYNC
  // ===========================================================================

  static Future<void> syncPersonToContact({
    required final BuildContext context,
    required final String firstName,
    required final String lastName,
    required final String phoneNumber,
    final String? email,
  }) async {
    if (_isInteractionActive) {
      _log.fine(
        'Sync UI interaction already active. Skipping duplicate request.',
      );
      return;
    }

    final uiContext = _getSafeUiContext(context);
    if (uiContext == null) return;

    if (!await ContactService.requestPermission()) return;

    try {
      _isInteractionActive = true;

      final contacts = await ContactService.getAllContacts();
      final normPhone = ContactService.normalizePhone(phoneNumber);

      Contact? existing;
      for (final c in contacts) {
        if (c.phones.any(
          (final p) =>
              ContactService.normalizePhone(p.normalizedNumber) == normPhone,
        )) {
          existing = c;
          break;
        }
      }

      if (!uiContext.mounted) return;

      if (existing == null) {
        // CREATE FLOW
        final confirm = await _showSimpleDialog(
          uiContext,
          title: 'Crea Contatto',
          content: 'Salva "$firstName $lastName" in rubrica?',
          confirmText: 'Salva',
          color: Colors.green,
        );

        if (confirm) {
          await ContactService.createContact(
            firstName: firstName,
            lastName: lastName,
            phone: phoneNumber,
            email: email,
          );
          if (uiContext.mounted) {
            showCustomSnackBar(context: context, message: 'Contatto salvato.');
          }
        }
      } else {
        // UPDATE FLOW
        if (ContactService.hasChanges(
          existing: existing,
          newFirst: firstName,
          newLast: lastName,
          newPhone: phoneNumber,
          newEmail: email,
        )) {
          final confirm = await showDialog<bool>(
            context: uiContext,
            barrierDismissible: false,
            builder: (final ctx) => SingleUpdateDialog(
              existing: existing!,
              newFirstName: firstName,
              newLastName: lastName,
              newPhone: phoneNumber,
              newEmail: email,
            ),
          );

          if (confirm == true) {
            await ContactService.updateContact(
              contact: existing,
              firstName: firstName,
              lastName: lastName,
              phone: phoneNumber,
              email: email,
            );
            if (uiContext.mounted) {
              showCustomSnackBar(
                context: context,
                message: 'Contatto aggiornato.',
              );
            }
          }
        } else {
          if (uiContext.mounted) {
            showCustomSnackBar(
              context: context,
              message: 'Contatto già sincronizzato.',
            );
            _log.fine('Contact already synced, no action needed.');
          }
        }
      }
    } catch (e, s) {
      _log.severe('Single sync failed', e, s);
    } finally {
      _isInteractionActive = false;
    }
  }

  // ===========================================================================
  // DELETE & IMPORT
  // ===========================================================================

  static Future<void> deletePersonFromContacts({
    required final BuildContext context,
    required final String phoneNumber,
  }) async {
    if (_isInteractionActive) return;

    final uiContext = _getSafeUiContext(context);
    if (uiContext == null) return;
    if (!await ContactService.requestPermission()) return;

    final contacts = await ContactService.getAllContacts();
    final normPhone = ContactService.normalizePhone(phoneNumber);

    try {
      _isInteractionActive = true;

      final target = contacts.cast<Contact?>().firstWhere(
        (final c) =>
            c != null &&
            c.phones.any(
              (final p) =>
                  ContactService.normalizePhone(p.normalizedNumber) ==
                  normPhone,
            ),
        orElse: () => null,
      );

      if (!uiContext.mounted) return;
      if (target == null) {
        showCustomSnackBar(context: context, message: 'Contatto non trovato.');
        return;
      }

      final confirm = await _showSimpleDialog(
        uiContext,
        title: 'Elimina',
        content: 'Eliminare "${target.displayName}" dalla rubrica?',
        confirmText: 'Elimina',
        color: Colors.red,
      );

      if (confirm) {
        await ContactService.deleteContact(target);
        if (uiContext.mounted) {
          showCustomSnackBar(context: context, message: 'Eliminato.');
        }
      }
    } catch (e) {
      _log.warning('Delete error', e);
    } finally {
      _isInteractionActive = false;
    }
  }

  static Future<Client?> pickContactAsClient() async {
    if (!await ContactService.requestPermission()) return null;

    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return null;

      final name = contact.name;
      final phone = contact.phones.isNotEmpty
          ? contact.phones.first.number
          : '';
      final email = contact.emails.isNotEmpty
          ? contact.emails.first.address
          : null;

      return Client(
        id: 'NOTUSED',
        firstName: name.first,
        lastName: name.last,
        phoneNumber: phone,
        email: email,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      _log.warning('Pick contact error', e);
      return null;
    }
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  static BuildContext? _getSafeUiContext(final BuildContext context) {
    if (Overlay.maybeOf(context) != null) return context;
    return Navigator.maybeOf(context)?.overlay?.context;
  }

  static void _showLoading(final BuildContext context) {
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  static Future<bool> _showSimpleDialog(
    final BuildContext context, {
    required final String title,
    required final String content,
    required final String confirmText,
    required final Color color,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (final ctx) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: color),
              child: Text(confirmText),
            ),
          ],
        ),
      ) ??
      false;
}
