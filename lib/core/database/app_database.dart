import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../logging/app_logger.dart';

part 'app_database.g.dart';

// ============================================================================
// TABLES — CORE (existing)
// ============================================================================

/// Appointments table
@DataClassName('AppointmentData')
class AppointmentsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → operators.id (DEVE essere nullable e con setNull)
  IntColumn get operatorId => integer().nullable().references(
    OperatorsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// FK → clients.id (DEVE essere nullable e con setNull)
  TextColumn get clientId => text().nullable().references(
    ClientsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// FK → cabins.id (DEVE essere nullable e con setNull)
  IntColumn get cabinId => integer().nullable().references(
    CabinsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  DateTimeColumn get startDateTime => dateTime()();

  DateTimeColumn get endDateTime => dateTime()();

  TextColumn get notes => text()
      .withLength(
        min: kMinAppointmentNotesLength,
        max: kMaxAppointmentNotesLength,
      )
      .nullable()();

  RealColumn get discount => real().withDefault(const Constant(0))();

  TextColumn get discountReason => text()
      .withLength(
        min: kMinAppointmentDiscountLength,
        max: kMaxAppointmentDiscountLength,
      )
      .nullable()();

  /// Note operatore post-trattamento (valutazione pelle, osservazioni...)
  TextColumn get operatorNotes => text()
      .withLength(
        min: kMinAppointmentOperatorNotesLength,
        max: kMaxAppointmentOperatorNotesLength,
      )
      .nullable()();

  /// Reazione pelle post-trattamento (es. "Nessuna", "Lieve arrossamento", "Sensibilità...")
  TextColumn get skinReaction => text()
      .withLength(
        min: kMinAppointmentSkinReactionLength,
        max: kMaxAppointmentSkinReactionLength,
      )
      .nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  /// Soft delete
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Operator blocked slots (ferie, assenze parziali, ecc.).
/// A blocked slot prevents new appointments from being created in that range
/// for the given operator and is rendered as a dimmed region in the calendar.
@DataClassName('OperatorBlockedSlot')
class OperatorBlockedSlotsTable extends Table {
  /// PK - UUID
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// Se questo campo è pieno, significa che il blocco fa parte di una serie,
  /// usare Uuid().v7()
  TextColumn get seriesId => text().nullable()();

  /// FK → clients.id
  IntColumn get operatorId =>
      integer().references(OperatorsTable, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get startDateTime => dateTime()();

  DateTimeColumn get endDateTime => dateTime()();

  /// Optional human-readable reason shown in the calendar (e.g. "Ferie estive")
  TextColumn get reason => text()
      .withLength(
        min: kMinOperatorBlockedSlotsReasonLength,
        max: kMaxOperatorBlockedSlotsReasonLength,
      )
      .nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  /// Soft delete
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Clients table
@DataClassName('Client')
class ClientsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// Client first name
  TextColumn get firstName => text().withLength(
    min: kMinClientFirstNameLength,
    max: kMaxClientFirstNameLength,
  )();

  /// Client last name
  TextColumn get lastName => text().withLength(
    min: kMinClientLastNameLength,
    max: kMaxClientLastNameLength,
  )();

  /// Phone number with country code
  TextColumn get phoneNumber => text().withLength(
    min: kMinClientPhoneNumberLength,
    max: kMaxClientPhoneNumberLength,
  )();

  /// Email address (optional)
  TextColumn get email => text()
      .withLength(min: kMinClientEmailLength, max: kMaxClientEmailLength)
      .nullable()();

  /// Client birth date (optional)
  DateTimeColumn get birthDate => dateTime().nullable()();

  /// Physical address (optional)
  TextColumn get address => text()
      .withLength(min: kMinClientAddressLength, max: kMaxClientAddressLength)
      .nullable()();

  /// Optional notes
  TextColumn get notes => text()
      .withLength(min: kMinClientNotesLength, max: kMaxClientNotesLength)
      .nullable()();

  /// Record creation timestamp
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  /// Last update timestamp
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  /// Soft delete
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Client tags table - for categorizing clients
@DataClassName('ClientTagData')
class ClientTagsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → clients.id
  TextColumn get clientId => text().references(
    ClientsTable,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Tag name (e.g., "VIP", "Allergica", "Preferisce Mattina")
  TextColumn get tag => text().withLength(
    min: 1,
    max: 50,
  )();

  /// Tag color in hex format (optional)
  TextColumn get colorHex => text().nullable()();

  /// Record creation timestamp
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (client_id, tag)',
  ];
}

/// Client product blacklist - products to never suggest to this client
@DataClassName('ClientProductBlacklistData')
class ClientProductBlacklistTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → clients.id
  TextColumn get clientId => text().references(
    ClientsTable,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// FK → products.id
  TextColumn get productId => text().references(
    ProductsTable,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Reason for blacklisting (optional)
  TextColumn get reason => text()
      .withLength(min: 1, max: 200)
      .nullable()();

  /// Record creation timestamp
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (client_id, product_id)',
  ];
}

/// Client technical sheet - stores detailed technical info for treatments
@DataClassName('ClientTechnicalSheetData')
class ClientTechnicalSheetsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → clients.id (one-to-one relationship)
  TextColumn get clientId => text().references(
    ClientsTable,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Skin type (e.g., "Secca", "Grassa", "Mista", "Normale", "Sensibile")
  TextColumn get skinType => text()
      .withLength(
        min: kMinTechnicalSheetSkinTypeLength,
        max: kMaxTechnicalSheetSkinTypeLength,
      )
      .nullable()();

  /// Skin conditions and concerns (e.g., acne, rosacea, hyperpigmentation)
  TextColumn get skinConditions => text()
      .withLength(
        min: kMinTechnicalSheetSkinConditionsLength,
        max: kMaxTechnicalSheetSkinConditionsLength,
      )
      .nullable()();

  /// Known allergies (products, ingredients, etc.)
  TextColumn get allergies => text()
      .withLength(
        min: kMinTechnicalSheetAllergiesLength,
        max: kMaxTechnicalSheetAllergiesLength,
      )
      .nullable()();

  /// Contraindications for treatments
  TextColumn get contraindications => text()
      .withLength(
        min: kMinTechnicalSheetContraindicationsLength,
        max: kMaxTechnicalSheetContraindicationsLength,
      )
      .nullable()();

  /// Current medications that might affect treatments
  TextColumn get currentMedications => text()
      .withLength(
        min: kMinTechnicalSheetCurrentMedicationsLength,
        max: kMaxTechnicalSheetCurrentMedicationsLength,
      )
      .nullable()();

  /// Previous aesthetic treatments history
  TextColumn get previousTreatments => text()
      .withLength(
        min: kMinTechnicalSheetPreviousTreatmentsLength,
        max: kMaxTechnicalSheetPreviousTreatmentsLength,
      )
      .nullable()();

  /// Machine settings and preferences (JSON or structured text)
  TextColumn get machineSettings => text()
      .withLength(
        min: kMinTechnicalSheetMachineSettingsLength,
        max: kMaxTechnicalSheetMachineSettingsLength,
      )
      .nullable()();

  /// Treatment goals and expectations
  TextColumn get treatmentGoals => text()
      .withLength(
        min: kMinTechnicalSheetTreatmentGoalsLength,
        max: kMaxTechnicalSheetTreatmentGoalsLength,
      )
      .nullable()();

  /// Medical notes (pregnancy, breastfeeding, conditions)
  TextColumn get medicalNotes => text()
      .withLength(
        min: kMinTechnicalSheetMedicalNotesLength,
        max: kMaxTechnicalSheetMedicalNotesLength,
      )
      .nullable()();

  /// Is pregnant
  BoolColumn get isPregnant => boolean().withDefault(const Constant(false))();

  /// Is breastfeeding
  BoolColumn get isBreastfeeding => boolean().withDefault(const Constant(false))();

  /// Has sun sensitivity
  BoolColumn get hasSunSensitivity => boolean().withDefault(const Constant(false))();

  /// Has herpes/simplex history (important for facial treatments)
  BoolColumn get hasHerpesHistory => boolean().withDefault(const Constant(false))();

  /// Has keloid scarring tendency
  BoolColumn get hasKeloidTendency => boolean().withDefault(const Constant(false))();

  /// Has diabetes
  BoolColumn get hasDiabetes => boolean().withDefault(const Constant(false))();

  /// Has pacemaker or electronic implants
  BoolColumn get hasPacemaker => boolean().withDefault(const Constant(false))();

  /// Fitzpatrick skin type scale (1-6)
  IntColumn get fitzpatrickType => integer().nullable()();

  /// Last update timestamp
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (client_id)',
  ];
}

/// Tabella dei Servizi (Catalogo)
@DataClassName('ServiceData')
class ServicesTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  TextColumn get name => text().withLength(
    min: kMinServiceNameLength,
    max: kMaxServiceNameLength,
  )();

  IntColumn get durationMinutes => integer().withDefault(const Constant(30))();

  RealColumn get price => real().withDefault(const Constant(0))();

  TextColumn get description => text()
      .withLength(
        min: kMinServiceDescriptionLength,
        max: kMaxServiceDescriptionLength,
      )
      .nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  /// Soft delete
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// JUNCTION TABLE (Molti-a-Molti) — Servizi associati ad un appuntamento.
/// Ora con PK propria (UUID) per permettere lo stesso servizio più volte.
@DataClassName('AppointmentServiceData')
class AppointmentServicesTable extends Table {
  /// PK propria — permette duplicati (es. 2× stesso servizio)
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → appointments.id
  TextColumn get appointmentId =>
      text().references(AppointmentsTable, #id, onDelete: KeyAction.cascade)();

  /// FK → services.id, NO CASCADE
  TextColumn get serviceId => text().references(ServicesTable, #id)();

  /// CONGELAMENTO DATI (Snapshot)
  /// Valori locked vengono copiati dalla ServicesTable alla prenotazione.
  RealColumn get lockedPrice => real()();

  IntColumn get lockedDuration => integer()();

  /// FK opzionale → package_items.id — se la seduta è scalata da un pacchetto
  TextColumn get packageItemId => text().nullable().references(
    PackageItemsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// FK opzionale → fidelity_cards.id — se pagata con carta fidelity
  TextColumn get fidelityCardId => text().nullable().references(
    FidelityCardsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Come viene pagato questo servizio nell'appuntamento.
  /// Valori: 'package', 'fidelity', 'direct'
  TextColumn get paymentSource =>
      text().withDefault(const Constant('direct'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cabins table - ID is the cabin number, manually assigned.
/// DEFAULT DATA LOADED ON SUPABASE, ON FIRST RUN DOWNLOAD IN LOCAL DB
@DataClassName('Cabin')
class CabinsTable extends Table {
  /// ID is the cabin number, manually assigned
  IntColumn get id => integer()();

  /// Data
  IntColumn get color => integer()(); // ARGB32 format

  /// Soft delete
  BoolColumn get isActive => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Operators table
/// DEFAULT DATA LOADED ON SUPABASE, ON FIRST RUN DOWNLOAD IN LOCAL DB
@DataClassName('Operator')
class OperatorsTable extends Table {
  /// ID is the operator number, manually assigned
  IntColumn get id => integer()();

  /// Data
  TextColumn get name => text().withLength(
    min: kMinOperatorsNameLength,
    max: kMaxOperatorsNameLength,
  )();

  /// Soft delete
  BoolColumn get isActive => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Global work hours (singleton - id always = [kIdWorkHours]).
/// DEFAULT DATA LOADED ON SUPABASE, ON FIRST RUN DOWNLOAD IN LOCAL DB
/// Used as the default displayed range for the calendar.
@DataClassName('WorkHours')
class WorkHoursTable extends Table {
  IntColumn get id => integer()();

  /// Opening time
  IntColumn get startHr => integer()();

  IntColumn get startMin => integer()();

  /// Closing time
  IntColumn get endHr => integer()();

  IntColumn get endMin => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// TABLES — PRODUCTS (Catalogo prodotti vendibili)
// ============================================================================

/// Catalogo prodotti disponibili per la vendita al cliente.
@DataClassName('ProductData')
class ProductsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  TextColumn get name => text().withLength(
    min: kMinProductNameLength,
    max: kMaxProductNameLength,
  )();

  TextColumn get description => text()
      .withLength(
        min: kMinProductDescriptionLength,
        max: kMaxProductDescriptionLength,
      )
      .nullable()();

  RealColumn get price => real().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  /// Soft delete
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// TABLES — QUOTES (Preventivi)
// ============================================================================

/// Preventivo: documento che riassume trattamenti/sedute offerte al cliente.
/// Può essere convertito in un pacchetto (Package) se accettato.
@DataClassName('QuoteData')
class QuotesTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → clients.id
  TextColumn get clientId => text().nullable().references(
    ClientsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Numero progressivo display (es. "PREV-2026-001"), gestito da UI
  TextColumn get quoteNumber => text().withLength(
    min: kMinQuoteNumberLength,
    max: kMaxQuoteNumberLength,
  )();

  /// Status: draft, sent, accepted, rejected, expired
  TextColumn get status => text().withDefault(const Constant('draft'))();

  /// Prezzo totale del preventivo
  RealColumn get totalPrice => real().withDefault(const Constant(0))();

  /// Sconto eventuale sul totale
  RealColumn get discountAmount => real().withDefault(const Constant(0))();

  /// Data di scadenza del preventivo (opzionale)
  DateTimeColumn get validUntil => dateTime().nullable()();

  /// Note in fondo al PDF
  TextColumn get notes => text()
      .withLength(min: kMinQuoteNotesLength, max: kMaxQuoteNotesLength)
      .nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  /// Soft delete
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Riga singola di un preventivo — un servizio con quantità di sedute.
@DataClassName('QuoteItemData')
class QuoteItemsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → quotes.id
  TextColumn get quoteId =>
      text().references(QuotesTable, #id, onDelete: KeyAction.cascade)();

  /// FK → services.id (riferimento al catalogo)
  TextColumn get serviceId => text().references(ServicesTable, #id)();

  /// Snapshot del nome servizio al momento della creazione
  TextColumn get lockedServiceName => text().withLength(
    min: kMinQuoteItemLockedNameLength,
    max: kMaxQuoteItemLockedNameLength,
  )();

  /// Snapshot del prezzo unitario al momento della creazione (prezzo base)
  RealColumn get lockedUnitPrice => real()();

  /// Numero di sedute proposte per questo servizio
  IntColumn get sessions => integer().withDefault(const Constant(1))();

  /// Tipo sconto: 'fixed' (fisso) o 'percentage' (percentuale)
  TextColumn get discountType =>
      text().withDefault(const Constant('fixed'))();

  /// Importo dello sconto (valore assoluto o percentuale)
  RealColumn get discountAmount => real().withDefault(const Constant(0))();

  /// Prezzo unitario dopo sconto (denormalizzato per performance)
  RealColumn get discountedUnitPrice => real().withDefault(const Constant(0))();

  /// Totale riga = discountedUnitPrice × sessions
  RealColumn get lineTotal => real()();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// TABLES — PACKAGES (Pacchetti servizi)
// ============================================================================

/// Pacchetto: bundle di servizi venduti insieme a un prezzo totale.
/// Può derivare da un preventivo accettato (quoteId) oppure essere creato
/// direttamente.
@DataClassName('PackageData')
class PackagesTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → clients.id
  TextColumn get clientId => text().nullable().references(
    ClientsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// FK opzionale → quotes.id (se derivato da preventivo accettato)
  TextColumn get quoteId => text().nullable().references(
    QuotesTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Nome display del pacchetto
  TextColumn get name => text().withLength(
    min: kMinPackageNameLength,
    max: kMaxPackageNameLength,
  )();

  /// Status: active, completed, expired, cancelled
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Prezzo totale del pacchetto (spesso scontato)
  RealColumn get totalPrice => real()();

  /// Totale incassato (denormalizzato, ricalcolabile da PaymentsTable)
  RealColumn get paidAmount => real().withDefault(const Constant(0))();

  /// Scadenza opzionale del pacchetto
  DateTimeColumn get expiresAt => dateTime().nullable()();

  /// Note
  TextColumn get notes => text()
      .withLength(min: kMinPackageNotesLength, max: kMaxPackageNotesLength)
      .nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  /// Soft delete
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Servizio incluso in un pacchetto con tracciamento delle sedute.
@DataClassName('PackageItemData')
class PackageItemsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → packages.id
  TextColumn get packageId =>
      text().references(PackagesTable, #id, onDelete: KeyAction.cascade)();

  /// FK → services.id (riferimento al catalogo)
  TextColumn get serviceId => text().references(ServicesTable, #id)();

  /// Snapshot del nome servizio
  TextColumn get lockedServiceName => text().withLength(
    min: kMinPackageItemLockedNameLength,
    max: kMaxPackageItemLockedNameLength,
  )();

  /// Snapshot del prezzo unitario
  RealColumn get lockedUnitPrice => real()();

  /// Numero totale di sedute incluse nel pacchetto per questo servizio
  IntColumn get totalSessions => integer()();

  /// Sedute già utilizzate (denormalizzato; source of truth =
  /// count di AppointmentServicesTable con packageItemId = this.id)
  IntColumn get usedSessions => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// TABLES — FIDELITY CARDS (Carte fedeltà con credito prepagato)
// ============================================================================

/// Carta fidelity con credito prepagato. Può essere un regalo.
@DataClassName('FidelityCardData')
class FidelityCardsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → clients.id
  TextColumn get clientId => text().nullable().references(
    ClientsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Codice univoco della carta (display)
  TextColumn get cardNumber => text().withLength(
    min: kMinFidelityCardNumberLength,
    max: kMaxFidelityCardNumberLength,
  )();

  /// Credito residuo (denormalizzato; source of truth =
  /// somma di FidelityTransactionsTable.amount)
  RealColumn get balance => real().withDefault(const Constant(0))();

  /// Se la carta è un regalo
  BoolColumn get isGift => boolean().withDefault(const Constant(false))();

  /// Nota di testo se la carta è un regalo
  TextColumn get giftNote => text()
      .withLength(
        min: kMinFidelityGiftNoteLength,
        max: kMaxFidelityGiftNoteLength,
      )
      .nullable()();

  /// Status: active, suspended, exhausted
  TextColumn get status => text().withDefault(const Constant('active'))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  /// Soft delete
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Movimento su carta fidelity: ricarica, utilizzo o rimborso.
@DataClassName('FidelityTransactionData')
class FidelityTransactionsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → fidelity_cards.id
  TextColumn get fidelityCardId => text().references(
    FidelityCardsTable,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Positivo = ricarica/rimborso, Negativo = utilizzo
  RealColumn get amount => real()();

  /// Tipo: topup, usage, refund
  TextColumn get type => text()();

  /// FK opzionale → appointments.id (se legato a un appuntamento)
  TextColumn get appointmentId => text().nullable().references(
    AppointmentsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Descrizione del movimento
  TextColumn get description => text()
      .withLength(
        min: kMinFidelityTransactionDescriptionLength,
        max: kMaxFidelityTransactionDescriptionLength,
      )
      .nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// TABLES — PAYMENTS (Storico pagamenti)
// ============================================================================

/// Pagamento singolo. Collegato ad almeno uno tra package, appointment,
/// o product sale (constraint applicativo, non DB).
@DataClassName('PaymentData')
class PaymentsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → clients.id
  TextColumn get clientId => text().nullable().references(
    ClientsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// FK opzionale → packages.id
  TextColumn get packageId => text().nullable().references(
    PackagesTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// FK opzionale → appointments.id
  TextColumn get appointmentId => text().nullable().references(
    AppointmentsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// FK opzionale → product_sales.id
  TextColumn get productSaleId => text().nullable().references(
    ProductSalesTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Importo pagato (positivo = incasso, negativo = storno/rimborso)
  RealColumn get amount => real()();

  /// Metodo: cash, card, transfer, fidelity
  TextColumn get paymentMethod => text().withDefault(
    const Constant('cash'),
  )();

  /// Note
  TextColumn get notes => text()
      .withLength(min: kMinPaymentNotesLength, max: kMaxPaymentNotesLength)
      .nullable()();

  /// Data del pagamento
  DateTimeColumn get paidAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// TABLES — PRODUCT SALES (Vendite prodotti)
// ============================================================================

/// Vendita di un prodotto a un cliente. Transazione separata dai servizi.
@DataClassName('ProductSaleData')
class ProductSalesTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v7())();

  /// FK → clients.id
  TextColumn get clientId => text().nullable().references(
    ClientsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// FK → products.id (no cascade — il prodotto potrebbe essere disattivato)
  TextColumn get productId => text().references(ProductsTable, #id)();

  /// Snapshot del nome prodotto al momento della vendita
  TextColumn get lockedProductName => text().withLength(
    min: kMinProductSaleLockedNameLength,
    max: kMaxProductSaleLockedNameLength,
  )();

  /// Snapshot del prezzo al momento della vendita
  RealColumn get lockedPrice => real()();

  /// Quantità venduta
  IntColumn get quantity => integer().withDefault(const Constant(1))();

  /// Totale riga = lockedPrice × quantity
  RealColumn get lineTotal => real()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  /// Soft delete
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// ============================================================================
// DATABASE
// ============================================================================

@DriftDatabase(
  tables: [
    // Core
    AppointmentsTable,
    OperatorBlockedSlotsTable,
    ClientsTable,
    ClientTagsTable,
    ClientProductBlacklistTable,
    ClientTechnicalSheetsTable,
    ServicesTable,
    AppointmentServicesTable,
    CabinsTable,
    OperatorsTable,
    WorkHoursTable,
    // Products
    ProductsTable,
    // Quotes
    QuotesTable,
    QuoteItemsTable,
    // Packages
    PackagesTable,
    PackageItemsTable,
    // Fidelity
    FidelityCardsTable,
    FidelityTransactionsTable,
    // Payments
    PaymentsTable,
    // Product Sales
    ProductSalesTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  factory AppDatabase() => _instance ??= AppDatabase._();

  AppDatabase._() : super(_openConnection());

  static AppDatabase? _instance;

  @override
  int get schemaVersion => 1;

  static final _log = AppLogger.getLogger(name: 'DriftDatabase');

  static QueryExecutor _openConnection() => driftDatabase(
    name: kDatabaseName,
    native: DriftNativeOptions(
      databaseDirectory: () async {
        // 1. Ottieni la cartella base (Application Support)
        final baseDir = await getApplicationSupportDirectory();

        // 2. Costruisci il path della tua sottocartella custom
        final dbDir = Directory(p.join(baseDir.path, kDatabaseDir));

        // 3. Crea la cartella se non esiste
        // ignore: avoid_slow_async_io
        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
        }

        // 4. COSTRUISCI IL PATH COMPLETO PER IL LOG
        final fullPath = p.join(dbDir.path, kDatabaseName);
        _log.info('DATABASE PATH: $fullPath.sqlite');

        // Restituisci la directory a drift_flutter
        return dbDir;
      },
    ),
  );

  static Future<void> requestResetOnNextLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDatabaseRequestResetKey, true);

    exit(0);
  }

  static Future<void> deleteDatabaseFiles() async {
    final baseDir = await getApplicationSupportDirectory();
    final dbPath = p.join(baseDir.path, kDatabaseDir, '$kDatabaseName.sqlite');

    for (final path in [
      dbPath,
      '$dbPath-wal',
      '$dbPath-shm',
      '$dbPath-journal',
    ]) {
      try {
        final file = File(path);
        // ignore: avoid_slow_async_io
        if (await file.exists()) {
          await file.delete();
          _log.info('Eliminato: $path');
        }
      } catch (e) {
        _log.warning('Impossibile eliminare $path: $e');
      }
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (final Migrator m) async {
      await m.createAll();
      _log.finest('Local database created (v$schemaVersion)');
    },
    onUpgrade: (final Migrator m, final int from, final int to) async {
      // No migrations needed — DB is recreated from scratch.
    },
    beforeOpen: (final details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
      await customStatement('PRAGMA temp_store = MEMORY');

      // Create indexes for frequently queried columns (idempotent - safe to run every time)
      await _createIndexes();

      // Check database integrity
      await _checkDatabaseIntegrity();
    },
  );

  Future<void> _checkDatabaseIntegrity() async {
    final result = await customSelect('PRAGMA integrity_check;').getSingle();
    final value = result.data.values.first;
    if (value != 'ok') {
      throw Exception('Database corruption detected: $value');
    }
  }

  /// Create indexes for frequently queried columns to improve query performance
  /// IF NOT EXISTS makes these idempotent - safe to run every time
  Future<void> _createIndexes() async {
    final indexStatements = [
      // Clients table indexes
      'CREATE INDEX IF NOT EXISTS idx_clients_phone ON clients_table(phone_number)',
      'CREATE INDEX IF NOT EXISTS idx_clients_email ON clients_table(email)',
      'CREATE INDEX IF NOT EXISTS idx_clients_name ON clients_table(last_name, first_name)',

      // Client tags indexes
      'CREATE INDEX IF NOT EXISTS idx_client_tags_client ON client_tags_table(client_id)',
      'CREATE INDEX IF NOT EXISTS idx_client_tags_tag ON client_tags_table(tag)',

      // Client product blacklist indexes
      'CREATE INDEX IF NOT EXISTS idx_client_blacklist_client ON client_product_blacklist_table(client_id)',
      'CREATE INDEX IF NOT EXISTS idx_client_blacklist_product ON client_product_blacklist_table(product_id)',

      // Client technical sheet indexes
      'CREATE INDEX IF NOT EXISTS idx_client_technical_sheet_client ON client_technical_sheets_table(client_id)',

      // Appointments table indexes
      'CREATE INDEX IF NOT EXISTS idx_appointments_client ON appointments_table(client_id)',
      'CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments_table(start_date_time)',
      'CREATE INDEX IF NOT EXISTS idx_appointments_operator ON appointments_table(operator_id)',
      'CREATE INDEX IF NOT EXISTS idx_appointments_cabin ON appointments_table(cabin_id)',
      'CREATE INDEX IF NOT EXISTS idx_appointments_active ON appointments_table(is_active)',

      // Appointment services indexes
      'CREATE INDEX IF NOT EXISTS idx_appt_services_appointment ON appointment_services_table(appointment_id)',
      'CREATE INDEX IF NOT EXISTS idx_appt_services_service ON appointment_services_table(service_id)',

      // Fidelity cards indexes
      'CREATE INDEX IF NOT EXISTS idx_fidelity_client ON fidelity_cards_table(client_id)',
      'CREATE INDEX IF NOT EXISTS idx_fidelity_card_number ON fidelity_cards_table(card_number)',

      // Package items indexes
      'CREATE INDEX IF NOT EXISTS idx_package_items_package ON package_items_table(package_id)',
      'CREATE INDEX IF NOT EXISTS idx_package_items_service ON package_items_table(service_id)',

      // Quotes indexes
      'CREATE INDEX IF NOT EXISTS idx_quotes_client ON quotes_table(client_id)',
      'CREATE INDEX IF NOT EXISTS idx_quotes_date ON quotes_table(created_at)',

      // Product sales indexes
      'CREATE INDEX IF NOT EXISTS idx_product_sales_product ON product_sales_table(product_id)',
      'CREATE INDEX IF NOT EXISTS idx_product_sales_date ON product_sales_table(created_at)',

      // Payments indexes (missing - required for financial queries)
      'CREATE INDEX IF NOT EXISTS idx_payments_client ON payments_table(client_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_package ON payments_table(package_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_appointment ON payments_table(appointment_id)',
      'CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON payments_table(paid_at)',

      // Fidelity transactions indexes (missing)
      'CREATE INDEX IF NOT EXISTS idx_fidelity_transactions_card ON fidelity_transactions_table(fidelity_card_id)',
      'CREATE INDEX IF NOT EXISTS idx_fidelity_transactions_type ON fidelity_transactions_table(type)',

      // Packages indexes (missing)
      'CREATE INDEX IF NOT EXISTS idx_packages_client ON packages_table(client_id)',
      'CREATE INDEX IF NOT EXISTS idx_packages_status ON packages_table(status)',
      'CREATE INDEX IF NOT EXISTS idx_packages_expires ON packages_table(expires_at)',

      // Quote items indexes (missing)
      'CREATE INDEX IF NOT EXISTS idx_quote_items_quote ON quote_items_table(quote_id)',
      'CREATE INDEX IF NOT EXISTS idx_quote_items_service ON quote_items_table(service_id)',

      // Operator blocked slots indexes (missing)
      'CREATE INDEX IF NOT EXISTS idx_blocked_slots_operator ON operator_blocked_slots_table(operator_id)',
      'CREATE INDEX IF NOT EXISTS idx_blocked_slots_date ON operator_blocked_slots_table(start_date_time)',
    ];

    for (final statement in indexStatements) {
      try {
        await customStatement(statement);
      } catch (e) {
        _log.warning('Failed to create index: $statement', e);
        // Continue with other indexes even if one fails
      }
    }

    _log.finest('Database indexes created/verified');
  }
}
