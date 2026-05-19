import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../logging/app_logger.dart';

/// Service handling low-level interactions with the device Address Book.
class ContactService {
  ContactService._();

  static final _log = AppLogger.getLogger(name: 'ContactService');

  // =====================
  // NORMALIZE
  // =====================

  static String normalizePhone(final String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return phone.startsWith('+') ? '+$digits' : digits;
  }

  // =====================
  // PERMISSION
  // =====================

  static Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      _log.warning('Permission denied: $status');
      return false;
    }
    return true;
  }

  // =====================
  // FETCH
  // =====================

  static Future<List<Contact>> getAllContacts() async {
    try {
      return await FlutterContacts.getAll(
        properties: ContactProperties.allProperties,
      );
    } catch (e) {
      _log.severe('Fetch contacts failed', e);
      return [];
    }
  }

  // =====================
  // CREATE
  // =====================

  static Future<void> createContact({
    required final String firstName,
    required final String lastName,
    required final String phone,
    final String? email,
  }) async {
    final contact = Contact(
      name: Name(first: firstName, last: lastName),
      phones: [
        Phone(
          number: phone,
          label: const Label(PhoneLabel.mobile),
          isPrimary: true,
        ),
      ],
      emails: (email != null && email.isNotEmpty)
          ? [
              Email(
                address: email,
                label: const Label(EmailLabel.work),
                isPrimary: true,
              ),
            ]
          : [],
    );

    await FlutterContacts.create(contact);
  }

  // =====================
  // UPDATE (SMART MERGE)
  // =====================

  static Future<void> updateContact({
    required final Contact contact,
    required final String firstName,
    required final String lastName,
    required final String phone,
    final String? email,
  }) async {
    final old = await FlutterContacts.get(
      contact.id!,
      properties: ContactProperties.allProperties,
    );
    if (old == null) return;

    final normPhone = normalizePhone(phone);

    // ---- PHONES
    final phones = List<Phone>.from(old.phones);

    final exists = phones.any(
      (final p) => normalizePhone(p.normalizedNumber ?? p.number) == normPhone,
    );

    if (!exists) {
      phones.add(
        Phone(
          number: phone,
          label: const Label(PhoneLabel.mobile),
          isPrimary: phones.isEmpty,
        ),
      );
    }

    // ---- EMAILS
    final emails = List<Email>.from(old.emails);

    if (email != null && email.isNotEmpty) {
      final exists = emails.any(
        (final e) => e.address.toLowerCase() == email.toLowerCase(),
      );

      if (!exists) {
        emails.add(
          Email(
            address: email,
            label: const Label(EmailLabel.work),
            isPrimary: emails.isEmpty,
          ),
        );
      }
    }

    // ---- NAME
    final updatedName = (old.name ?? const Name()).copyWith(
      first: firstName,
      last: lastName,
    );

    await FlutterContacts.update(
      old.copyWith(name: updatedName, phones: phones, emails: emails),
    );
  }

  // =====================
  // MATCHING
  // =====================

  static Contact? findBestMatch({
    required final List<Contact> contacts,
    required final String phone,
    required final String firstName,
    required final String lastName,
  }) {
    final norm = normalizePhone(phone);

    // 1. match telefono (più forte)
    final phoneMatches = contacts
        .where(
          (final c) => c.phones.any(
            (final p) => normalizePhone(p.normalizedNumber ?? p.number) == norm,
          ),
        )
        .toList();

    if (phoneMatches.length == 1) return phoneMatches.first;

    // 2. fallback nome (solo se unico)
    final targetName = '$firstName $lastName'.toLowerCase();

    final nameMatches = contacts.where((final c) {
      final name = '${c.name?.first ?? ''} ${c.name?.last ?? ''}'.toLowerCase();
      return name == targetName;
    }).toList();

    if (nameMatches.length == 1) return nameMatches.first;

    return null;
  }

  // =====================
  // CHANGE DETECTION
  // =====================

  static bool hasChanges({
    required final Contact existing,
    required final String newFirst,
    required final String newLast,
    required final String newPhone,
    final String? newEmail,
  }) {
    final nameChanged =
        (existing.name?.first ?? '') != newFirst ||
        (existing.name?.last ?? '') != newLast;

    final norm = normalizePhone(newPhone);

    final phoneExists = existing.phones.any(
      (final p) => normalizePhone(p.normalizedNumber ?? p.number) == norm,
    );

    var emailChanged = false;

    if (newEmail != null && newEmail.isNotEmpty) {
      emailChanged = !existing.emails.any(
        (final e) => e.address.toLowerCase() == newEmail.toLowerCase(),
      );
    }

    return nameChanged || !phoneExists || emailChanged;
  }

  static Future<bool> deleteContact(final Contact contact) async {
    try {
      if (contact.id == null) {
        _log.warning('Delete failed: contact has no ID');
        return false;
      }

      await FlutterContacts.delete(contact.id!);
      return true;
    } catch (e) {
      _log.severe('Delete contact failed', e);
      return false;
    }
  }
}
