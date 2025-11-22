import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../logging/app_logger.dart';

/// Service handling low-level interactions with the device Address Book.
class ContactService {
  ContactService._();

  static final _log = AppLogger.getLogger(name: 'ContactService');

  /// Normalize phone number for comparison (digits only)
  static String normalizePhone(final String phone) =>
      phone.replaceAll(RegExp(r'[^\d+]'), '');

  /// Request contacts permission
  static Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      _log.warning('Contact permission denied: $status');
      return false;
    }
    return true;
  }

  /// Fetch all contacts optimized for diffing (No photos)
  static Future<List<Contact>> getAllContacts() async {
    try {
      return await FlutterContacts.getContacts(
        withProperties: true,
        withAccounts: true,
        withPhoto: true,
      );
    } catch (e) {
      _log.severe('Failed to fetch contacts', e);
      return [];
    }
  }

  /// Create a new contact
  static Future<void> createContact({
    required final String firstName,
    required final String lastName,
    required final String phone,
    final String? email,
  }) async {
    final contact = Contact()
      ..name = Name(first: firstName, last: lastName)
      ..phones = [Phone(phone)];

    if (email != null && email.isNotEmpty) {
      contact.emails = [Email(email, label: EmailLabel.work)];
    }
    await contact.insert();
  }

  /// Update an existing contact
  static Future<void> updateContact({
    required final Contact contact,
    required final String firstName,
    required final String lastName,
    required final String phone,
    final String? email,
  }) async {
    // Re-fetch full contact including photo/notes before update to avoid data loss
    // (FlutterContacts updates the whole object)
    final fullContact = await FlutterContacts.getContact(
      contact.id,
      withAccounts: true,
    );
    if (fullContact == null) return;

    fullContact.name = Name(first: firstName, last: lastName);

    // Update Phone
    final normPhone = normalizePhone(phone);
    final hasPhone = fullContact.phones.any(
      (final p) => normalizePhone(p.normalizedNumber) == normPhone,
    );

    if (!hasPhone) {
      if (fullContact.phones.isEmpty) {
        fullContact.phones = [Phone(phone)];
      } else {
        // Update primary phone, keep others if exist
        fullContact.phones[0] = Phone(phone);
      }
    }

    // Update Email
    if (email != null && email.isNotEmpty) {
      final hasEmail = fullContact.emails.any((final e) => e.address == email);
      if (!hasEmail) {
        if (fullContact.emails.isEmpty) {
          fullContact.emails = [Email(email, label: EmailLabel.work)];
        } else {
          fullContact.emails[0] = Email(email, label: EmailLabel.work);
        }
      }
    }

    await fullContact.update();
  }

  /// Delete contact
  static Future<void> deleteContact(final Contact contact) async {
    await contact.delete();
  }

  /// Check if specific fields have changed
  static bool hasChanges({
    required final Contact existing,
    required final String newFirst,
    required final String newLast,
    required final String newPhone,
    final String? newEmail,
  }) {
    if (existing.name.first != newFirst || existing.name.last != newLast) {
      return true;
    }

    final normPhone = normalizePhone(newPhone);
    final hasPhone = existing.phones.any(
      (final p) => normalizePhone(p.normalizedNumber) == normPhone,
    );
    if (!hasPhone) return true;

    if (newEmail != null && newEmail.isNotEmpty) {
      final hasEmail = existing.emails.any((final e) => e.address == newEmail);
      if (!hasEmail) return true;
    }

    return false;
  }
}
