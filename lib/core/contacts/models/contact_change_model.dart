import 'package:flutter_contacts/flutter_contacts.dart';

enum ContactChangeType { create, update }

/// Represents a pending change to be applied to the device contacts
class PendingContactChange {
  PendingContactChange({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.type,
    this.email,
    this.existingContact,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final ContactChangeType type;
  final Contact? existingContact;

  // UI State
  var isSelected = true;
}
