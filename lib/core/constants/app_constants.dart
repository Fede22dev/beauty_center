import 'dart:io';

bool get kIsWindows => Platform.isWindows;

const kDefaultAppAnimationsDuration = Duration(milliseconds: 350);

// ============================================================================
// DATABASE
// ============================================================================

const kDatabaseDir = 'database';
const kDatabaseName = 'beauty_center';
const kDatabaseRequestResetKey = 'reset_db';

const kLastSyncBufferDuration = Duration(minutes: 5);
const kLastSyncTimePrefix = 'last_sync_time_';
const kLastSyncTimeAppointmentsKey = '${kLastSyncTimePrefix}appointments';
const kLastSyncTimeOperatorsBlockedSlotsKey =
    'l${kLastSyncTimePrefix}operators_blocked_slots';
const kLastSyncTimeClientsKey = 'l${kLastSyncTimePrefix}clients';
const kLastSyncTimeServicesKey = '${kLastSyncTimePrefix}services';
const kLastSyncTimeAppointmentServicesKey =
    '${kLastSyncTimePrefix}appointment_services';

// APPOINTMENTS
const kMinAppointmentNotesLength = 0;
const kMaxAppointmentNotesLength = 10000;

const kMinAppointmentDiscountLength = 0;
const kMaxAppointmentDiscountLength = 1000;

const kMinAppointmentOperatorNotesLength = 0;
const kMaxAppointmentOperatorNotesLength = 5000;

const kMinAppointmentSkinReactionLength = 0;
const kMaxAppointmentSkinReactionLength = 1000;

// OPERATOR BLOCKED SLOTS
const kMinOperatorBlockedSlotsReasonLength = 0;
const kMaxOperatorBlockedSlotsReasonLength = 1000;

// CLIENTS
const kMinClientFirstNameLength = 1;
const kMaxClientFirstNameLength = 100;

const kMinClientLastNameLength = 1;
const kMaxClientLastNameLength = 100;

const kMinClientPhoneNumberLength = 10;
const kMaxClientPhoneNumberLength = 15;

const kMinClientEmailLength = 0;
const kMaxClientEmailLength = 255;

const kMinClientAddressLength = 0;
const kMaxClientAddressLength = 1000;

const kMinClientNotesLength = 0;
const kMaxClientNotesLength = 10000;

// CLIENT TECHNICAL SHEET
const kMinTechnicalSheetSkinTypeLength = 0;
const kMaxTechnicalSheetSkinTypeLength = 100;

const kMinTechnicalSheetSkinConditionsLength = 0;
const kMaxTechnicalSheetSkinConditionsLength = 1000;

const kMinTechnicalSheetAllergiesLength = 0;
const kMaxTechnicalSheetAllergiesLength = 2000;

const kMinTechnicalSheetContraindicationsLength = 0;
const kMaxTechnicalSheetContraindicationsLength = 2000;

const kMinTechnicalSheetCurrentMedicationsLength = 0;
const kMaxTechnicalSheetCurrentMedicationsLength = 1000;

const kMinTechnicalSheetPreviousTreatmentsLength = 0;
const kMaxTechnicalSheetPreviousTreatmentsLength = 3000;

const kMinTechnicalSheetMachineSettingsLength = 0;
const kMaxTechnicalSheetMachineSettingsLength = 3000;

const kMinTechnicalSheetTreatmentGoalsLength = 0;
const kMaxTechnicalSheetTreatmentGoalsLength = 2000;

const kMinTechnicalSheetMedicalNotesLength = 0;
const kMaxTechnicalSheetMedicalNotesLength = 5000;

// SERVICES
const kMinServiceNameLength = 1;
const kMaxServiceNameLength = 100;

const kMinServiceDescriptionLength = 0;
const kMaxServiceDescriptionLength = 1000;

// PRODUCTS
const kMinProductNameLength = 1;
const kMaxProductNameLength = 100;

const kMinProductDescriptionLength = 0;
const kMaxProductDescriptionLength = 1000;

// QUOTES
const kMinQuoteNumberLength = 1;
const kMaxQuoteNumberLength = 50;

const kMinQuoteNotesLength = 0;
const kMaxQuoteNotesLength = 5000;

// QUOTE ITEMS
const kMinQuoteItemLockedNameLength = 1;
const kMaxQuoteItemLockedNameLength = 100;

// PACKAGES
const kMinPackageNameLength = 1;
const kMaxPackageNameLength = 200;

const kMinPackageNotesLength = 0;
const kMaxPackageNotesLength = 5000;

// PACKAGE ITEMS
const kMinPackageItemLockedNameLength = 1;
const kMaxPackageItemLockedNameLength = 100;

// FIDELITY CARDS
const kMinFidelityCardNumberLength = 1;
const kMaxFidelityCardNumberLength = 50;

const kMinFidelityGiftNoteLength = 0;
const kMaxFidelityGiftNoteLength = 1000;

// FIDELITY TRANSACTIONS
const kMinFidelityTransactionDescriptionLength = 0;
const kMaxFidelityTransactionDescriptionLength = 500;

// PAYMENTS
const kMinPaymentNotesLength = 0;
const kMaxPaymentNotesLength = 1000;

/// Metodi di pagamento supportati
enum PaymentMethod {
  cash('Contanti'),
  card('Carta'),
  transfer('Bonifico'),
  fidelity('Carta Fidelity');

  final String displayName;
  const PaymentMethod(this.displayName);

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

/// Tipo di sconto: valore fisso o percentuale
enum DiscountType {
  fixed('€ Fisso'),
  percentage('% Percentuale');

  final String displayName;
  const DiscountType(this.displayName);
}

// PRODUCT SALES
const kMinProductSaleLockedNameLength = 1;
const kMaxProductSaleLockedNameLength = 100;

// DISCOUNT INPUT
const kMaxDiscountPercentage = 100;

// CABINS

// OPERATORS
const kMinOperatorsNameLength = 1;
const kMaxOperatorsNameLength = 20;

// WORK HOURS
const kIdWorkHours = 1;

// SYNC KEYS (new tables)
const kLastSyncTimeProductsKey = '${kLastSyncTimePrefix}products';
const kLastSyncTimeQuotesKey = '${kLastSyncTimePrefix}quotes';
const kLastSyncTimeQuoteItemsKey = '${kLastSyncTimePrefix}quote_items';
const kLastSyncTimePackagesKey = '${kLastSyncTimePrefix}packages';
const kLastSyncTimePackageItemsKey = '${kLastSyncTimePrefix}package_items';
const kLastSyncTimeFidelityCardsKey = '${kLastSyncTimePrefix}fidelity_cards';
const kLastSyncTimeFidelityTransactionsKey =
    '${kLastSyncTimePrefix}fidelity_transactions';
const kLastSyncTimePaymentsKey = '${kLastSyncTimePrefix}payments';
const kLastSyncTimeProductSalesKey = '${kLastSyncTimePrefix}product_sales';
const kLastSyncTimeClientTechnicalSheetsKey = '${kLastSyncTimePrefix}client_technical_sheets';
const kLastSyncTimeClientTagsKey = '${kLastSyncTimePrefix}client_tags';
const kLastSyncTimeClientProductBlacklistKey = '${kLastSyncTimePrefix}client_product_blacklist';

// ============================================================================
// SUPABASE
// ============================================================================

const kSupabaseUrlKeySecureStorageKey = 'supabase_url';
const kSupabaseAnonKeySecureStorageKey = 'supabase_anonkey';

// ============================================================================
// CALENDAR
// ============================================================================

const kMinCalendarYear = 2025;
const kMaxCalendarYear = 2100;

// ============================================================================
// SETTINGS
// ============================================================================

// CABINS
const kMinCabinsCount = 1;

// OPERATORS
const kMinOperatorsCount = 1;
