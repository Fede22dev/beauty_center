/// This file defines all Supabase tables and columns as constants
library;

/// Postgres schema
class PostgresSchema {
  static const public = 'public';
}

/// Realtime channel names
class RealtimeChannels {
  static const appointmentsChanges = 'appointments_changes';
  static const operatorBlockedSlotsChanges = 'operator_blocked_slots_changes';
  static const clientsChanges = 'clients_changes';
  static const servicesChanges = 'services_changes';
  static const appointmentServicesChanges = 'appointment_services_changes';
  static const cabinsChanges = 'cabins_changes';
  static const operatorsChanges = 'operators_changes';
  static const workHoursChanges = 'work_hours_changes';
  // New tables
  static const productsChanges = 'products_changes';
  static const quotesChanges = 'quotes_changes';
  static const quoteItemsChanges = 'quote_items_changes';
  static const packagesChanges = 'packages_changes';
  static const packageItemsChanges = 'package_items_changes';
  static const fidelityCardsChanges = 'fidelity_cards_changes';
  static const fidelityTransactionsChanges = 'fidelity_transactions_changes';
  static const paymentsChanges = 'payments_changes';
  static const productSalesChanges = 'product_sales_changes';
  // Client related tables
  static const clientTagsChanges = 'client_tags_changes';
  static const clientTechnicalSheetsChanges = 'client_technical_sheets_changes';
  static const clientProductBlacklistChanges = 'client_product_blacklist_changes';
}

/// Base class for all table schemas
abstract class SupabaseTableSchema {
  const SupabaseTableSchema();

  /// Table name in Supabase
  String get tableName;

  /// Realtime channel name
  String get channelName;

  @override
  String toString() => tableName;
}

// ============================================================================
// TABLE SCHEMAS — CORE
// ============================================================================

class SupabaseAppointmentsTable extends SupabaseTableSchema {
  const SupabaseAppointmentsTable._();

  static const instance = SupabaseAppointmentsTable._();

  @override
  String get tableName => 'appointments';

  @override
  String get channelName => RealtimeChannels.appointmentsChanges;

  // Column names
  static const id = 'id';
  static const operatorId = 'operator_id';
  static const clientId = 'client_id';
  static const cabinId = 'cabin_id';
  static const startDateTime = 'start_datetime';
  static const endDateTime = 'end_datetime';
  static const notes = 'notes';
  static const discount = 'discount';
  static const discountReason = 'discount_reason';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const isActive = 'is_active';
}

class SupabaseOperatorBlockedSlotsTable extends SupabaseTableSchema {
  const SupabaseOperatorBlockedSlotsTable._();

  static const instance = SupabaseOperatorBlockedSlotsTable._();

  @override
  String get tableName => 'operator_blocked_slots';

  @override
  String get channelName => RealtimeChannels.operatorBlockedSlotsChanges;

  // Column names
  static const id = 'id';
  static const seriesId = 'series_id';
  static const operatorId = 'operator_id';
  static const startDateTime = 'start_datetime';
  static const endDateTime = 'end_datetime';
  static const reason = 'reason';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const isActive = 'is_active';
}

/// Clients table schema
class SupabaseClientsTable extends SupabaseTableSchema {
  const SupabaseClientsTable._();

  static const instance = SupabaseClientsTable._();

  @override
  String get tableName => 'clients';

  @override
  String get channelName => RealtimeChannels.clientsChanges;

  // Column names
  static const id = 'id';
  static const firstName = 'first_name';
  static const lastName = 'last_name';
  static const phoneNumber = 'phone_number';
  static const email = 'email';
  static const birthDate = 'birth_date';
  static const address = 'address';
  static const notes = 'notes';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const isActive = 'is_active';
}

/// Service table schema
class SupabaseServicesTable extends SupabaseTableSchema {
  const SupabaseServicesTable._();

  static const instance = SupabaseServicesTable._();

  @override
  String get tableName => 'services';

  @override
  String get channelName => RealtimeChannels.servicesChanges;

  // Column names
  static const id = 'id';
  static const name = 'name';
  static const durationMinutes = 'duration_minutes';
  static const price = 'price';
  static const description = 'description';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const isActive = 'is_active';
}

/// Appointment services table schema
class SupabaseAppointmentServicesTable extends SupabaseTableSchema {
  const SupabaseAppointmentServicesTable._();

  static const instance = SupabaseAppointmentServicesTable._();

  @override
  String get tableName => 'appointment_services';

  @override
  String get channelName => RealtimeChannels.appointmentServicesChanges;

  // Column names
  static const id = 'id';
  static const appointmentId = 'appointment_id';
  static const serviceId = 'service_id';
  static const lockedPrice = 'locked_price';
  static const lockedDuration = 'locked_duration';
  static const packageItemId = 'package_item_id';
  static const fidelityCardId = 'fidelity_card_id';
  static const paymentSource = 'payment_source';
}

/// Cabins table schema
class SupabaseCabinsTable extends SupabaseTableSchema {
  const SupabaseCabinsTable._();

  static const instance = SupabaseCabinsTable._();

  @override
  String get tableName => 'cabins';

  @override
  String get channelName => RealtimeChannels.cabinsChanges;

  // Column names
  static const id = 'id';
  static const color = 'color';
  static const isActive = 'is_active';
}

/// Operators table schema
class SupabaseOperatorsTable extends SupabaseTableSchema {
  const SupabaseOperatorsTable._();

  static const instance = SupabaseOperatorsTable._();

  @override
  String get tableName => 'operators';

  @override
  String get channelName => RealtimeChannels.operatorsChanges;

  // Column names
  static const id = 'id';
  static const name = 'name';
  static const isActive = 'is_active';
}

/// Work hours table schema
class SupabaseWorkHoursTable extends SupabaseTableSchema {
  const SupabaseWorkHoursTable._();

  static const instance = SupabaseWorkHoursTable._();

  @override
  String get tableName => 'work_hours';

  @override
  String get channelName => RealtimeChannels.workHoursChanges;

  // Column names
  static const id = 'id';
  static const startHr = 'start_hr';
  static const startMin = 'start_min';
  static const endHr = 'end_hr';
  static const endMin = 'end_min';
}

// ============================================================================
// TABLE SCHEMAS — PRODUCTS
// ============================================================================

class SupabaseProductsTable extends SupabaseTableSchema {
  const SupabaseProductsTable._();

  static const instance = SupabaseProductsTable._();

  @override
  String get tableName => 'products';

  @override
  String get channelName => RealtimeChannels.productsChanges;

  // Column names
  static const id = 'id';
  static const name = 'name';
  static const description = 'description';
  static const price = 'price';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const isActive = 'is_active';
}

// ============================================================================
// TABLE SCHEMAS — QUOTES
// ============================================================================

class SupabaseQuotesTable extends SupabaseTableSchema {
  const SupabaseQuotesTable._();

  static const instance = SupabaseQuotesTable._();

  @override
  String get tableName => 'quotes';

  @override
  String get channelName => RealtimeChannels.quotesChanges;

  // Column names
  static const id = 'id';
  static const clientId = 'client_id';
  static const quoteNumber = 'quote_number';
  static const status = 'status';
  static const totalPrice = 'total_price';
  static const discountAmount = 'discount_amount';
  static const validUntil = 'valid_until';
  static const notes = 'notes';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const isActive = 'is_active';
}

class SupabaseQuoteItemsTable extends SupabaseTableSchema {
  const SupabaseQuoteItemsTable._();

  static const instance = SupabaseQuoteItemsTable._();

  @override
  String get tableName => 'quote_items';

  @override
  String get channelName => RealtimeChannels.quoteItemsChanges;

  // Column names
  static const id = 'id';
  static const quoteId = 'quote_id';
  static const serviceId = 'service_id';
  static const lockedServiceName = 'locked_service_name';
  static const lockedUnitPrice = 'locked_unit_price';
  static const sessions = 'sessions';
  static const discountType = 'discount_type';
  static const discountAmount = 'discount_amount';
  static const discountedUnitPrice = 'discounted_unit_price';
  static const lineTotal = 'line_total';
}

// ============================================================================
// TABLE SCHEMAS — PACKAGES
// ============================================================================

class SupabasePackagesTable extends SupabaseTableSchema {
  const SupabasePackagesTable._();

  static const instance = SupabasePackagesTable._();

  @override
  String get tableName => 'packages';

  @override
  String get channelName => RealtimeChannels.packagesChanges;

  // Column names
  static const id = 'id';
  static const clientId = 'client_id';
  static const quoteId = 'quote_id';
  static const name = 'name';
  static const status = 'status';
  static const totalPrice = 'total_price';
  static const paidAmount = 'paid_amount';
  static const expiresAt = 'expires_at';
  static const notes = 'notes';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const isActive = 'is_active';
}

class SupabasePackageItemsTable extends SupabaseTableSchema {
  const SupabasePackageItemsTable._();

  static const instance = SupabasePackageItemsTable._();

  @override
  String get tableName => 'package_items';

  @override
  String get channelName => RealtimeChannels.packageItemsChanges;

  // Column names
  static const id = 'id';
  static const packageId = 'package_id';
  static const serviceId = 'service_id';
  static const lockedServiceName = 'locked_service_name';
  static const lockedUnitPrice = 'locked_unit_price';
  static const totalSessions = 'total_sessions';
  static const usedSessions = 'used_sessions';
}

// ============================================================================
// TABLE SCHEMAS — FIDELITY CARDS
// ============================================================================

class SupabaseFidelityCardsTable extends SupabaseTableSchema {
  const SupabaseFidelityCardsTable._();

  static const instance = SupabaseFidelityCardsTable._();

  @override
  String get tableName => 'fidelity_cards';

  @override
  String get channelName => RealtimeChannels.fidelityCardsChanges;

  // Column names
  static const id = 'id';
  static const clientId = 'client_id';
  static const cardNumber = 'card_number';
  static const balance = 'balance';
  static const isGift = 'is_gift';
  static const giftNote = 'gift_note';
  static const status = 'status';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const isActive = 'is_active';
}

class SupabaseFidelityTransactionsTable extends SupabaseTableSchema {
  const SupabaseFidelityTransactionsTable._();

  static const instance = SupabaseFidelityTransactionsTable._();

  @override
  String get tableName => 'fidelity_transactions';

  @override
  String get channelName => RealtimeChannels.fidelityTransactionsChanges;

  // Column names
  static const id = 'id';
  static const fidelityCardId = 'fidelity_card_id';
  static const amount = 'amount';
  static const type = 'type';
  static const appointmentId = 'appointment_id';
  static const description = 'description';
  static const createdAt = 'created_at';
}

// ============================================================================
// TABLE SCHEMAS — PAYMENTS
// ============================================================================

class SupabasePaymentsTable extends SupabaseTableSchema {
  const SupabasePaymentsTable._();

  static const instance = SupabasePaymentsTable._();

  @override
  String get tableName => 'payments';

  @override
  String get channelName => RealtimeChannels.paymentsChanges;

  // Column names
  static const id = 'id';
  static const clientId = 'client_id';
  static const packageId = 'package_id';
  static const appointmentId = 'appointment_id';
  static const productSaleId = 'product_sale_id';
  static const amount = 'amount';
  static const paymentMethod = 'payment_method';
  static const notes = 'notes';
  static const paidAt = 'paid_at';
  static const createdAt = 'created_at';
}

// ============================================================================
// TABLE SCHEMAS — CLIENT RELATED
// ============================================================================

class SupabaseClientTagsTable extends SupabaseTableSchema {
  const SupabaseClientTagsTable._();

  static const instance = SupabaseClientTagsTable._();

  @override
  String get tableName => 'client_tags';

  @override
  String get channelName => RealtimeChannels.clientTagsChanges;

  // Column names
  static const id = 'id';
  static const clientId = 'client_id';
  static const tag = 'tag';
  static const colorHex = 'color_hex';
  static const createdAt = 'created_at';
}

class SupabaseClientTechnicalSheetsTable extends SupabaseTableSchema {
  const SupabaseClientTechnicalSheetsTable._();

  static const instance = SupabaseClientTechnicalSheetsTable._();

  @override
  String get tableName => 'client_technical_sheets';

  @override
  String get channelName => RealtimeChannels.clientTechnicalSheetsChanges;

  // Column names
  static const id = 'id';
  static const clientId = 'client_id';
  static const skinType = 'skin_type';
  static const skinConditions = 'skin_conditions';
  static const allergies = 'allergies';
  static const contraindications = 'contraindications';
  static const currentMedications = 'current_medications';
  static const previousTreatments = 'previous_treatments';
  static const machineSettings = 'machine_settings';
  static const treatmentGoals = 'treatment_goals';
  static const medicalNotes = 'medical_notes';
  static const isPregnant = 'is_pregnant';
  static const isBreastfeeding = 'is_breastfeeding';
  static const hasSunSensitivity = 'has_sun_sensitivity';
  static const hasHerpesHistory = 'has_herpes_history';
  static const hasKeloidTendency = 'has_keloid_tendency';
  static const hasDiabetes = 'has_diabetes';
  static const hasPacemaker = 'has_pacemaker';
  static const fitzpatrickType = 'fitzpatrick_type';
  static const updatedAt = 'updated_at';
}

class SupabaseClientProductBlacklistTable extends SupabaseTableSchema {
  const SupabaseClientProductBlacklistTable._();

  static const instance = SupabaseClientProductBlacklistTable._();

  @override
  String get tableName => 'client_product_blacklist';

  @override
  String get channelName => RealtimeChannels.clientProductBlacklistChanges;

  // Column names
  static const id = 'id';
  static const clientId = 'client_id';
  static const productId = 'product_id';
  static const reason = 'reason';
  static const createdAt = 'created_at';
}

// ============================================================================
// TABLE SCHEMAS — PRODUCT SALES
// ============================================================================

class SupabaseProductSalesTable extends SupabaseTableSchema {
  const SupabaseProductSalesTable._();

  static const instance = SupabaseProductSalesTable._();

  @override
  String get tableName => 'product_sales';

  @override
  String get channelName => RealtimeChannels.productSalesChanges;

  // Column names
  static const id = 'id';
  static const clientId = 'client_id';
  static const productId = 'product_id';
  static const lockedProductName = 'locked_product_name';
  static const lockedPrice = 'locked_price';
  static const quantity = 'quantity';
  static const lineTotal = 'line_total';
  static const createdAt = 'created_at';
  static const isActive = 'is_active';
}

// ============================================================================
// USAGE HELPER
// ============================================================================

/// Helper class to access all table schemas
/// Usage: SupabaseSchema.cabins.tableName
abstract class SupabaseSchema {
  // Core
  static const appointments = SupabaseAppointmentsTable.instance;
  static const operatorBlockedSlots =
      SupabaseOperatorBlockedSlotsTable.instance;
  static const clients = SupabaseClientsTable.instance;
  static const services = SupabaseServicesTable.instance;
  static const appointmentServices = SupabaseAppointmentServicesTable.instance;
  static const cabins = SupabaseCabinsTable.instance;
  static const operators = SupabaseOperatorsTable.instance;
  static const workHours = SupabaseWorkHoursTable.instance;
  // Products
  static const products = SupabaseProductsTable.instance;
  // Quotes
  static const quotes = SupabaseQuotesTable.instance;
  static const quoteItems = SupabaseQuoteItemsTable.instance;
  // Packages
  static const packages = SupabasePackagesTable.instance;
  static const packageItems = SupabasePackageItemsTable.instance;
  // Fidelity
  static const fidelityCards = SupabaseFidelityCardsTable.instance;
  static const fidelityTransactions =
      SupabaseFidelityTransactionsTable.instance;
  // Payments
  static const payments = SupabasePaymentsTable.instance;
  // Product Sales
  static const productSales = SupabaseProductSalesTable.instance;
  // Client related tables
  static const clientTags = SupabaseClientTagsTable.instance;
  static const clientTechnicalSheets = SupabaseClientTechnicalSheetsTable.instance;
  static const clientProductBlacklist = SupabaseClientProductBlacklistTable.instance;
}
