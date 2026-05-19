-- ============================================================
-- SUPABASE SQL SETUP - BEAUTY CENTER
-- Ordine corretto per dipendenze FK
-- ============================================================

-- =========================
-- LEVEL 0: TABELLE BASE (nessuna FK)
-- =========================

-- CLIENTS
CREATE TABLE clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name text NOT NULL CHECK (char_length(first_name) BETWEEN 1 AND 100),
  last_name text NOT NULL CHECK (char_length(last_name) BETWEEN 1 AND 100),
  phone_number text NOT NULL CHECK (char_length(phone_number) BETWEEN 10 AND 15),
  email text NULL CHECK (char_length(email) BETWEEN 0 AND 255),
  birth_date timestamp NULL,
  address text NULL CHECK (char_length(address) BETWEEN 0 AND 1000),
  notes text NULL CHECK (char_length(notes) BETWEEN 0 AND 10000),
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  is_active boolean DEFAULT true
);

-- PRODUCTS
CREATE TABLE products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  description text NULL CHECK (char_length(description) BETWEEN 0 AND 1000),
  price numeric NOT NULL DEFAULT 0.0,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  is_active boolean DEFAULT true
);

-- SERVICES
CREATE TABLE services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  duration_minutes integer NOT NULL DEFAULT 30,
  price numeric NOT NULL DEFAULT 0.0,
  description text NULL CHECK (char_length(description) BETWEEN 0 AND 1000),
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  is_active boolean DEFAULT true
);

-- CABINS
CREATE TABLE cabins (
  id integer PRIMARY KEY,
  color bigint NOT NULL,
  is_active boolean DEFAULT false
);

-- OPERATORS
CREATE TABLE operators (
  id integer PRIMARY KEY,
  name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 20),
  is_active boolean DEFAULT false
);

-- WORK HOURS (singleton)
CREATE TABLE work_hours (
  id integer PRIMARY KEY,
  start_hr integer NOT NULL,
  start_min integer NOT NULL,
  end_hr integer NOT NULL,
  end_min integer NOT NULL
);

-- =========================
-- LEVEL 1: TABELLE CON FK A LIVELLO 0
-- =========================

-- QUOTES
CREATE TABLE quotes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES clients(id) ON DELETE SET NULL,
  quote_number text NOT NULL CHECK (char_length(quote_number) BETWEEN 1 AND 50),
  status text DEFAULT 'draft',
  total_price numeric DEFAULT 0.0,
  discount_amount numeric DEFAULT 0.0,
  valid_until timestamp NULL,
  notes text NULL CHECK (char_length(notes) BETWEEN 0 AND 5000),
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  is_active boolean DEFAULT true
);

-- FIDELITY CARDS
CREATE TABLE fidelity_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES clients(id) ON DELETE SET NULL,
  card_number text NOT NULL CHECK (char_length(card_number) BETWEEN 1 AND 50),
  balance numeric DEFAULT 0.0,
  is_gift boolean DEFAULT false,
  gift_note text NULL CHECK (char_length(gift_note) BETWEEN 0 AND 1000),
  status text DEFAULT 'active',
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  is_active boolean DEFAULT true
);

-- CLIENT TAGS
CREATE TABLE client_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  tag text NOT NULL CHECK (char_length(tag) BETWEEN 1 AND 50),
  color_hex text NULL,
  created_at timestamp DEFAULT now(),
  UNIQUE (client_id, tag)
);

-- CLIENT PRODUCT BLACKLIST
CREATE TABLE client_product_blacklist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  reason text NULL CHECK (char_length(reason) BETWEEN 0 AND 200),
  created_at timestamp DEFAULT now(),
  UNIQUE (client_id, product_id)
);

-- CLIENT TECHNICAL SHEET
CREATE TABLE client_technical_sheets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  skin_type text NULL CHECK (char_length(skin_type) BETWEEN 0 AND 100),
  skin_conditions text NULL CHECK (char_length(skin_conditions) BETWEEN 0 AND 1000),
  allergies text NULL CHECK (char_length(allergies) BETWEEN 0 AND 2000),
  contraindications text NULL CHECK (char_length(contraindications) BETWEEN 0 AND 2000),
  current_medications text NULL CHECK (char_length(current_medications) BETWEEN 0 AND 1000),
  previous_treatments text NULL CHECK (char_length(previous_treatments) BETWEEN 0 AND 3000),
  machine_settings text NULL CHECK (char_length(machine_settings) BETWEEN 0 AND 3000),
  treatment_goals text NULL CHECK (char_length(treatment_goals) BETWEEN 0 AND 2000),
  medical_notes text NULL CHECK (char_length(medical_notes) BETWEEN 0 AND 5000),
  is_pregnant boolean DEFAULT false,
  is_breastfeeding boolean DEFAULT false,
  has_sun_sensitivity boolean DEFAULT false,
  has_herpes_history boolean DEFAULT false,
  has_keloid_tendency boolean DEFAULT false,
  has_diabetes boolean DEFAULT false,
  has_pacemaker boolean DEFAULT false,
  fitzpatrick_type integer NULL CHECK (fitzpatrick_type BETWEEN 1 AND 6),
  updated_at timestamp DEFAULT now(),
  UNIQUE (client_id)
);

-- PRODUCT SALES
CREATE TABLE product_sales (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES clients(id) ON DELETE SET NULL,
  product_id uuid NOT NULL REFERENCES products(id),
  locked_product_name text NOT NULL CHECK (char_length(locked_product_name) BETWEEN 1 AND 100),
  locked_price numeric NOT NULL,
  quantity integer DEFAULT 1,
  line_total numeric NOT NULL,
  created_at timestamp DEFAULT now(),
  is_active boolean DEFAULT true
);

-- =========================
-- LEVEL 2: TABELLE CON FK A LIVELLO 0 E 1
-- =========================

-- APPOINTMENTS
CREATE TABLE appointments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  operator_id integer REFERENCES operators(id) ON DELETE SET NULL,
  client_id uuid REFERENCES clients(id) ON DELETE SET NULL,
  cabin_id integer REFERENCES cabins(id) ON DELETE SET NULL,
  start_date_time timestamp NOT NULL,
  end_date_time timestamp NOT NULL,
  notes text CHECK (char_length(notes) BETWEEN 0 AND 10000),
  discount numeric NOT NULL DEFAULT 0.0,
  discount_reason text CHECK (char_length(discount_reason) BETWEEN 0 AND 1000),
  operator_notes text CHECK (char_length(operator_notes) BETWEEN 0 AND 5000),
  skin_reaction text CHECK (char_length(skin_reaction) BETWEEN 0 AND 1000),
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  is_active boolean DEFAULT true
);

-- OPERATOR BLOCKED SLOTS
CREATE TABLE operator_blocked_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  series_id uuid NULL,
  operator_id integer REFERENCES operators(id) ON DELETE CASCADE,
  start_date_time timestamp NOT NULL,
  end_date_time timestamp NOT NULL,
  reason text CHECK (char_length(reason) BETWEEN 0 AND 1000),
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  is_active boolean DEFAULT true
);

-- PACKAGES
CREATE TABLE packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES clients(id) ON DELETE SET NULL,
  quote_id uuid REFERENCES quotes(id) ON DELETE SET NULL,
  name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 200),
  status text DEFAULT 'active',
  total_price numeric NOT NULL,
  paid_amount numeric DEFAULT 0.0,
  expires_at timestamp NULL,
  notes text NULL CHECK (char_length(notes) BETWEEN 0 AND 5000),
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  is_active boolean DEFAULT true
);

-- QUOTE ITEMS
CREATE TABLE quote_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_id uuid NOT NULL REFERENCES quotes(id) ON DELETE CASCADE,
  service_id uuid NOT NULL REFERENCES services(id),
  locked_service_name text NOT NULL CHECK (char_length(locked_service_name) BETWEEN 1 AND 100),
  locked_unit_price numeric NOT NULL DEFAULT 0.0,
  sessions integer DEFAULT 1,
  discount_type text DEFAULT 'fixed',
  discount_amount numeric DEFAULT 0.0,
  discounted_unit_price numeric DEFAULT 0.0,
  line_total numeric NOT NULL DEFAULT 0.0,
  created_at timestamp DEFAULT now()
);

-- PACKAGE ITEMS
CREATE TABLE package_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id uuid NOT NULL REFERENCES packages(id) ON DELETE CASCADE,
  service_id uuid NOT NULL REFERENCES services(id),
  locked_service_name text NOT NULL CHECK (char_length(locked_service_name) BETWEEN 1 AND 100),
  locked_unit_price numeric NOT NULL,
  total_sessions integer NOT NULL,
  used_sessions integer DEFAULT 0
);

-- =========================
-- LEVEL 3: TABELLE CON FK COMPLESSE (dipendono da livelli precedenti)
-- =========================

-- FIDELITY TRANSACTIONS
CREATE TABLE fidelity_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fidelity_card_id uuid NOT NULL REFERENCES fidelity_cards(id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  type text NOT NULL,
  appointment_id uuid REFERENCES appointments(id) ON DELETE SET NULL,
  description text NULL CHECK (char_length(description) BETWEEN 0 AND 500),
  created_at timestamp DEFAULT now()
);

-- APPOINTMENT_SERVICES (Junction Table with UUID PK to allow duplicate services per appointment)
CREATE TABLE appointment_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id uuid NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  service_id uuid NOT NULL REFERENCES services(id) ON DELETE RESTRICT,
  locked_price numeric NOT NULL,
  locked_duration integer NOT NULL,
  package_item_id uuid NULL REFERENCES package_items(id) ON DELETE SET NULL,
  fidelity_card_id uuid NULL REFERENCES fidelity_cards(id) ON DELETE SET NULL,
  payment_source text DEFAULT 'direct',
  UNIQUE (appointment_id, id)
);

-- PAYMENTS
CREATE TABLE payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES clients(id) ON DELETE SET NULL,
  package_id uuid REFERENCES packages(id) ON DELETE SET NULL,
  appointment_id uuid REFERENCES appointments(id) ON DELETE SET NULL,
  product_sale_id uuid REFERENCES product_sales(id) ON DELETE SET NULL,
  amount numeric NOT NULL,
  payment_method text DEFAULT 'cash',
  notes text NULL CHECK (char_length(notes) BETWEEN 0 AND 1000),
  paid_at timestamp DEFAULT now(),
  created_at timestamp DEFAULT now()
);


-- =========================
-- REALTIME CHANNEL SETUP
-- =========================

-- APPOINTMENTS
ALTER TABLE public.appointments REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.appointments;

-- OPERATOR BLOCKED SLOTS
ALTER TABLE public.operator_blocked_slots REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.operator_blocked_slots;

-- CLIENTS
ALTER TABLE public.clients REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.clients;

-- SERVICES
ALTER TABLE public.services REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.services;

-- APPOINTMENT SERVICES
ALTER TABLE public.appointment_services REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.appointment_services;

-- CABINS
ALTER TABLE public.cabins REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.cabins;

-- OPERATORS
ALTER TABLE public.operators REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.operators;

-- WORK HOURS
ALTER TABLE public.work_hours REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.work_hours;

-- PRODUCTS
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.products;

-- QUOTES
ALTER TABLE public.quotes REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.quotes;

-- QUOTE ITEMS
ALTER TABLE public.quote_items REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.quote_items;

-- PACKAGES
ALTER TABLE public.packages REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.packages;

-- PACKAGE ITEMS
ALTER TABLE public.package_items REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.package_items;

-- FIDELITY CARDS
ALTER TABLE public.fidelity_cards REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.fidelity_cards;

-- FIDELITY TRANSACTIONS
ALTER TABLE public.fidelity_transactions REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.fidelity_transactions;

-- PAYMENTS
ALTER TABLE public.payments REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.payments;

-- PRODUCT SALES
ALTER TABLE public.product_sales REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.product_sales;

-- CLIENT TAGS
ALTER TABLE public.client_tags REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.client_tags;

-- CLIENT PRODUCT BLACKLIST
ALTER TABLE public.client_product_blacklist REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.client_product_blacklist;

-- CLIENT TECHNICAL SHEETS
ALTER TABLE public.client_technical_sheets REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.client_technical_sheets;


-- =========================
-- SETUP RLS
-- =========================

-- Enable RLS
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE operator_blocked_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE cabins ENABLE ROW LEVEL SECURITY;
ALTER TABLE operators ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE quote_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE fidelity_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE fidelity_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_product_blacklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_technical_sheets ENABLE ROW LEVEL SECURITY;


-- Policy for appointments
CREATE POLICY appointments_all ON appointments
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for operator_blocked_slots
CREATE POLICY operator_blocked_slots_all ON operator_blocked_slots
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for clients
CREATE POLICY clients_all ON clients
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for services
CREATE POLICY services_all ON services
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for appointment_services
CREATE POLICY appointment_services_all ON appointment_services
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for cabins
CREATE POLICY cabins_all ON cabins
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for operators
CREATE POLICY operators_all ON operators
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for work_hours
CREATE POLICY work_hours_all ON work_hours
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for products
CREATE POLICY products_all ON products
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for quotes
CREATE POLICY quotes_all ON quotes
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for quote_items
CREATE POLICY quote_items_all ON quote_items
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for packages
CREATE POLICY packages_all ON packages
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for package_items
CREATE POLICY package_items_all ON package_items
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for fidelity_cards
CREATE POLICY fidelity_cards_all ON fidelity_cards
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for fidelity_transactions
CREATE POLICY fidelity_transactions_all ON fidelity_transactions
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for payments
CREATE POLICY payments_all ON payments
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for product_sales
CREATE POLICY product_sales_all ON product_sales
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for client_tags
CREATE POLICY client_tags_all ON client_tags
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for client_product_blacklist
CREATE POLICY client_product_blacklist_all ON client_product_blacklist
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy for client_technical_sheets
CREATE POLICY client_technical_sheets_all ON client_technical_sheets
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);


-- =========================
-- GRANT PERMISSIONS
-- =========================

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;

-- Grant table permissions to authenticated role
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =========================
-- INSERT DEFAULT DATA
-- =========================

-- CABINS
INSERT INTO cabins (id, color, is_active) VALUES
(1, 4294923905, true),  -- Hot Pink
(2, 4281559295, false), -- Vivid Blue
(3, 4278250614, false), -- Bright Green
(4, 4294944000, false), -- Vibrant Orange
(5, 4289331455, false), -- Electric Purple
(6, 4294963200, false), -- Lemon Yellow
(7, 4278256037, false), -- Teal
(8, 4294921554, false), -- Red Accent
(9, 4283653374, false), -- Indigo Accent
(10, 4278236115, false), -- Emerald Green
(11, 4294940672, false), -- Deep Orange Accent
(12, 4292210681, false), -- Magenta
(13, 4284797975, false), -- Lime Green
(14, 4278255615, false), -- Cyan Bright
(15, 4294956800, false); -- Amber Accent

-- OPERATORS
INSERT INTO operators (id, name, is_active) VALUES
(1, 'Sara', true),
(2, 'Emma', false),
(3, 'Luca', false),
(4, 'Olivia', false),
(5, 'Mia', false),
(6, 'Leo', false),
(7, 'Noah', false),
(8, 'Eva', false),
(9, 'Marco', false),
(10, 'Elisa', false);

-- WORK HOURS
INSERT INTO work_hours (id, start_hr, start_min, end_hr, end_min) VALUES
(1, 9, 0, 20, 0);


-- =========================
-- INDEXES FOR PERFORMANCE
-- =========================

-- Clients indexes
CREATE INDEX IF NOT EXISTS idx_clients_phone ON clients(phone_number);
CREATE INDEX IF NOT EXISTS idx_clients_email ON clients(email);
CREATE INDEX IF NOT EXISTS idx_clients_name ON clients(last_name, first_name);

-- Appointments indexes
CREATE INDEX IF NOT EXISTS idx_appointments_client ON appointments(client_id);
CREATE INDEX IF NOT EXISTS idx_appointments_date ON appointments(start_date_time);
CREATE INDEX IF NOT EXISTS idx_appointments_operator ON appointments(operator_id);
CREATE INDEX IF NOT EXISTS idx_appointments_cabin ON appointments(cabin_id);
CREATE INDEX IF NOT EXISTS idx_appointments_active ON appointments(is_active);

-- Appointment services indexes
CREATE INDEX IF NOT EXISTS idx_appt_services_appointment ON appointment_services(appointment_id);
CREATE INDEX IF NOT EXISTS idx_appt_services_service ON appointment_services(service_id);

-- Fidelity cards indexes
CREATE INDEX IF NOT EXISTS idx_fidelity_client ON fidelity_cards(client_id);
CREATE INDEX IF NOT EXISTS idx_fidelity_card_number ON fidelity_cards(card_number);

-- Package indexes
CREATE INDEX IF NOT EXISTS idx_packages_client ON packages(client_id);
CREATE INDEX IF NOT EXISTS idx_packages_status ON packages(status);

-- Package items indexes
CREATE INDEX IF NOT EXISTS idx_package_items_package ON package_items(package_id);
CREATE INDEX IF NOT EXISTS idx_package_items_service ON package_items(service_id);

-- Quotes indexes
CREATE INDEX IF NOT EXISTS idx_quotes_client ON quotes(client_id);
CREATE INDEX IF NOT EXISTS idx_quotes_date ON quotes(created_at);

-- Quote items indexes
CREATE INDEX IF NOT EXISTS idx_quote_items_quote ON quote_items(quote_id);
CREATE INDEX IF NOT EXISTS idx_quote_items_service ON quote_items(service_id);
CREATE INDEX IF NOT EXISTS idx_quote_items_created ON quote_items(created_at);

-- Product sales indexes
CREATE INDEX IF NOT EXISTS idx_product_sales_product ON product_sales(product_id);
CREATE INDEX IF NOT EXISTS idx_product_sales_date ON product_sales(created_at);

-- Payments indexes
CREATE INDEX IF NOT EXISTS idx_payments_client ON payments(client_id);
CREATE INDEX IF NOT EXISTS idx_payments_package ON payments(package_id);
CREATE INDEX IF NOT EXISTS idx_payments_appointment ON payments(appointment_id);

-- Fidelity transactions indexes
CREATE INDEX IF NOT EXISTS idx_fidelity_transactions_card ON fidelity_transactions(fidelity_card_id);

-- Client tags indexes
CREATE INDEX IF NOT EXISTS idx_client_tags_client ON client_tags(client_id);
CREATE INDEX IF NOT EXISTS idx_client_tags_tag ON client_tags(tag);

-- Client product blacklist indexes
CREATE INDEX IF NOT EXISTS idx_client_blacklist_client ON client_product_blacklist(client_id);
CREATE INDEX IF NOT EXISTS idx_client_blacklist_product ON client_product_blacklist(product_id);

-- Client technical sheet indexes
CREATE INDEX IF NOT EXISTS idx_client_technical_sheet_client ON client_technical_sheets(client_id);


-- ============================================================
-- VINCOLI CHECK MINIMI (Bloccano dati impossibili)
-- ============================================================

-- Pagamento: almeno un riferimento deve esistere
-- Questo previene pagamenti "orfani" che non si sa a cosa si riferiscono
ALTER TABLE payments
ADD CONSTRAINT chk_payment_has_reference
CHECK (
  package_id IS NOT NULL OR
  appointment_id IS NOT NULL OR
  product_sale_id IS NOT NULL
);

-- Pagamento: importo non può essere zero
-- Un pagamento con importo zero è semanticamente invalido
ALTER TABLE payments
ADD CONSTRAINT chk_payment_amount_not_zero
CHECK (amount <> 0);

-- Fidelity: saldo non può essere negativo
-- Protegge da errori di calcolo o race conditions
ALTER TABLE fidelity_cards
ADD CONSTRAINT chk_fidelity_balance_not_negative
CHECK (balance >= 0);

-- Pacchetto: sedute utilizzate non possono superare il totale
ALTER TABLE package_items
ADD CONSTRAINT chk_used_sessions_valid
CHECK (used_sessions >= 0 AND used_sessions <= total_sessions);

-- Pacchetto: pagato non può superare il totale
ALTER TABLE packages
ADD CONSTRAINT chk_paid_not_exceed_total
CHECK (paid_amount >= 0 AND paid_amount <= total_price);

-- Quantità vendite: deve essere positiva
ALTER TABLE product_sales
ADD CONSTRAINT chk_quantity_positive
CHECK (quantity > 0);

-- Prezzi: non possono essere negativi
ALTER TABLE product_sales
ADD CONSTRAINT chk_price_not_negative
CHECK (locked_price >= 0);

ALTER TABLE appointment_services
ADD CONSTRAINT chk_service_price_not_negative
CHECK (locked_price >= 0);

-- ============================================================
-- INDICI PER PERFORMANCE E CONSISTENZA
-- ============================================================

-- Indice per prevenire pagamenti duplicati sulla stessa entità
-- Nota: questo è un indice parziale, non un vincolo unico assoluto
-- perché potremmo voler supportare pagamenti multipli (rate)
CREATE INDEX IF NOT EXISTS idx_payments_entity_lookup
ON payments(package_id, appointment_id, product_sale_id);

-- Indice per verificare rapidamente pagamenti orfani
CREATE INDEX IF NOT EXISTS idx_payments_orphan_check
ON payments((package_id IS NULL), (appointment_id IS NULL), (product_sale_id IS NULL))
WHERE package_id IS NULL AND appointment_id IS NULL AND product_sale_id IS NULL;

-- Indici per lookup rapido
CREATE INDEX IF NOT EXISTS idx_payments_client ON payments(client_id);
CREATE INDEX IF NOT EXISTS idx_fidelity_transactions_card ON fidelity_transactions(fidelity_card_id);
CREATE INDEX IF NOT EXISTS idx_package_items_package ON package_items(package_id);

-- ============================================================
-- FUNCTION PER VERIFICA INTEGRITÀ (Diagnostica)
-- ============================================================

-- Funzione: Controlla pagamenti orfani
CREATE OR REPLACE FUNCTION find_orphan_payments()
RETURNS TABLE (
  payment_id UUID,
  amount NUMERIC,
  client_id UUID,
  created_at TIMESTAMP
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.amount,
    p.client_id,
    p.created_at
  FROM payments p
  WHERE p.package_id IS NULL
    AND p.appointment_id IS NULL
    AND p.product_sale_id IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Funzione: Controlla saldi fidelity negativi
CREATE OR REPLACE FUNCTION find_negative_balances()
RETURNS TABLE (
  card_id UUID,
  balance NUMERIC,
  client_id UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT fc.id, fc.balance, fc.client_id
  FROM fidelity_cards fc
  WHERE fc.balance < 0;
END;
$$ LANGUAGE plpgsql;

-- Funzione: Controlla sedute pacchetto invalide
CREATE OR REPLACE FUNCTION find_invalid_package_sessions()
RETURNS TABLE (
  item_id UUID,
  used INTEGER,
  total INTEGER,
  package_id UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT pi.id, pi.used_sessions, pi.total_sessions, pi.package_id
  FROM package_items pi
  WHERE pi.used_sessions < 0
     OR pi.used_sessions > pi.total_sessions;
END;
$$ LANGUAGE plpgsql;

-- Funzione: Controlla pagamenti che superano il totale pacchetto
CREATE OR REPLACE FUNCTION find_overpaid_packages()
RETURNS TABLE (
  package_id UUID,
  total_price NUMERIC,
  paid_amount NUMERIC,
  difference NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.total_price,
    p.paid_amount,
    (p.paid_amount - p.total_price) AS difference
  FROM packages p
  WHERE p.paid_amount > p.total_price;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- VIEW PER MONITORAGGIO
-- ============================================================

-- View: Pagamenti potenzialmente duplicati (stessa entità, stesso importo, stesso giorno)
CREATE OR REPLACE VIEW v_potential_duplicate_payments AS
SELECT
  p1.id AS payment_1_id,
  p2.id AS payment_2_id,
  p1.amount,
  p1.package_id,
  p1.appointment_id,
  p1.product_sale_id,
  p1.created_at
FROM payments p1
JOIN payments p2 ON (
  (p1.package_id = p2.package_id OR p1.appointment_id = p2.appointment_id OR p1.product_sale_id = p2.product_sale_id)
  AND p1.amount = p2.amount
  AND p1.id < p2.id
  AND ABS(EXTRACT(EPOCH FROM (p1.created_at - p2.created_at))) < 60 -- nello stesso minuto
);

-- View: Riepilogo finanziario giornaliero
CREATE OR REPLACE VIEW v_daily_financial_summary AS
SELECT
  DATE(p.paid_at) AS date,
  p.payment_method,
  COUNT(*) AS transaction_count,
  SUM(CASE WHEN p.amount > 0 THEN p.amount ELSE 0 END) AS total_income,
  SUM(CASE WHEN p.amount < 0 THEN ABS(p.amount) ELSE 0 END) AS total_refunds,
  SUM(p.amount) AS net_amount
FROM payments p
GROUP BY DATE(p.paid_at), p.payment_method
ORDER BY DATE(p.paid_at) DESC, p.payment_method;
