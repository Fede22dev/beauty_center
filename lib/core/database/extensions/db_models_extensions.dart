import 'package:flutter/material.dart' as material show Color, TimeOfDay;

import '../app_database.dart';

// ============================================================================
// EXTENSIONS (models helpers)
// ============================================================================

extension AppointmentExtension on AppointmentData {}

extension OperatorBlockedSlotExtension on OperatorBlockedSlot {}

extension ClientExtension on Client {}

extension ServiceExtension on ServiceData {}

extension AppointmentServiceExtension on AppointmentServiceData {
  /// Whether this service is paid via a package
  bool get isFromPackage => paymentSource == 'package';

  /// Whether this service is paid via a fidelity card
  bool get isFromFidelity => paymentSource == 'fidelity';

  /// Whether this service is paid directly (no package/fidelity)
  bool get isDirect => paymentSource == 'direct';
}

extension CabinExtension on Cabin {
  material.Color get colorValue => material.Color(color);
}

extension OperatorExtension on Operator {}

extension WorkHoursExtension on WorkHours {
  material.TimeOfDay get startTime =>
      material.TimeOfDay(hour: startHr, minute: startMin);

  material.TimeOfDay get endTime =>
      material.TimeOfDay(hour: endHr, minute: endMin);

  int get workDayMinutes {
    final start = startHr * 60 + startMin;
    final end = endHr * 60 + endMin;
    return end - start;
  }
}

// ============================================================================
// NEW MODEL EXTENSIONS
// ============================================================================

extension ProductExtension on ProductData {}

extension QuoteExtension on QuoteData {
  /// Whether the quote can still be edited (only drafts)
  bool get isEditable => status == 'draft';

  /// Whether the quote can be converted to a package
  bool get isAcceptable => status == 'sent' || status == 'draft';

  /// Net total after discount
  double get netTotal => totalPrice - discountAmount;
}

extension QuoteItemExtension on QuoteItemData {}

extension PackageExtension on PackageData {
  /// Residuo da pagare
  double get remainingBalance => totalPrice - paidAmount;

  /// Whether the package is fully paid
  bool get isFullyPaid => paidAmount >= totalPrice;

  /// Whether the package is currently usable
  bool get isUsable => status == 'active';
}

extension PackageItemExtension on PackageItemData {
  /// Sedute rimanenti
  int get remainingSessions => totalSessions - usedSessions;

  /// Whether all sessions have been used
  bool get isExhausted => usedSessions >= totalSessions;

  /// Usage percentage (0.0 to 1.0)
  double get usageProgress =>
      totalSessions > 0 ? usedSessions / totalSessions : 0.0;
}

extension FidelityCardExtension on FidelityCardData {
  /// Whether the card has available credit
  bool get hasCredit => balance > 0;

  /// Whether the card is currently usable
  bool get isUsable => status == 'active' && balance > 0;
}

extension FidelityTransactionExtension on FidelityTransactionData {
  /// Whether this is a credit (topup/refund) or debit (usage)
  bool get isCredit => amount > 0;

  bool get isDebit => amount < 0;
}

extension PaymentExtension on PaymentData {
  /// Whether this is a refund/reversal
  bool get isRefund => amount < 0;
}

extension ProductSaleExtension on ProductSaleData {}
