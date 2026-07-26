-- Agenda360 — schema inicial (multi-tenant, shared schema + RLS)
-- Ver docs/DATABASE.md para o racional de cada decisão.
-- PostgreSQL 14+.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "btree_gist"; -- EXCLUDE USING gist com uuid/timestamptz

-- =========================================================================
-- tenants
-- =========================================================================
CREATE TABLE tenants (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug          text NOT NULL UNIQUE,
    name          text NOT NULL,
    segment       text NOT NULL DEFAULT 'barbershop',
    is_active     boolean NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tenant_branding (
    tenant_id       uuid PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
    display_name    text NOT NULL,
    logo_url        text,
    icon_url        text,
    primary_color   text,
    secondary_color text
);

-- =========================================================================
-- professionals
-- =========================================================================
CREATE TABLE professionals (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name        text NOT NULL,
    phone       text,
    is_active   boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_professionals_tenant ON professionals(tenant_id);

-- =========================================================================
-- services
-- =========================================================================
CREATE TABLE services (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name              text NOT NULL,
    duration_minutes  integer NOT NULL CHECK (duration_minutes > 0),
    price_cents       integer CHECK (price_cents IS NULL OR price_cents >= 0),
    is_active         boolean NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_services_tenant ON services(tenant_id);

-- =========================================================================
-- professional_services (N:N)
-- =========================================================================
CREATE TABLE professional_services (
    tenant_id        uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    professional_id  uuid NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    service_id       uuid NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    PRIMARY KEY (professional_id, service_id)
);

CREATE INDEX idx_professional_services_tenant ON professional_services(tenant_id);

-- =========================================================================
-- business_hours
-- =========================================================================
CREATE TABLE business_hours (
    tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    weekday     smallint NOT NULL CHECK (weekday BETWEEN 0 AND 6),
    opens_at    time,
    closes_at   time,
    is_closed   boolean NOT NULL DEFAULT false,
    PRIMARY KEY (tenant_id, weekday),
    CHECK (is_closed OR (opens_at IS NOT NULL AND closes_at IS NOT NULL AND opens_at < closes_at))
);

-- =========================================================================
-- blocked_slots
-- =========================================================================
CREATE TABLE blocked_slots (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id        uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    professional_id  uuid NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    starts_at        timestamptz NOT NULL,
    ends_at          timestamptz NOT NULL,
    reason           text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    CHECK (starts_at < ends_at)
);

CREATE INDEX idx_blocked_slots_tenant_professional
    ON blocked_slots(tenant_id, professional_id, starts_at);

-- =========================================================================
-- clients
-- =========================================================================
CREATE TABLE clients (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name        text NOT NULL,
    phone       text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_clients_tenant_phone UNIQUE (tenant_id, phone)
);

-- =========================================================================
-- appointments
-- =========================================================================
CREATE TABLE appointments (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id        uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    client_id        uuid NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
    professional_id  uuid NOT NULL REFERENCES professionals(id) ON DELETE RESTRICT,
    service_id       uuid NOT NULL REFERENCES services(id) ON DELETE RESTRICT,
    starts_at        timestamptz NOT NULL,
    ends_at          timestamptz NOT NULL,
    status           text NOT NULL DEFAULT 'scheduled'
                         CHECK (status IN ('scheduled', 'confirmed', 'cancelled', 'completed', 'no_show')),
    cancelled_at     timestamptz,
    cancel_reason    text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CHECK (starts_at < ends_at),
    -- Impede overlap de horários para o mesmo profissional, mesmo sob concorrência.
    -- Agendamentos cancelados não contam para a exclusão.
    EXCLUDE USING gist (
        professional_id WITH =,
        tstzrange(starts_at, ends_at) WITH &&
    ) WHERE (status <> 'cancelled')
);

CREATE INDEX idx_appointments_tenant_professional_starts
    ON appointments(tenant_id, professional_id, starts_at);
CREATE INDEX idx_appointments_tenant_client
    ON appointments(tenant_id, client_id);

-- =========================================================================
-- promotions
-- =========================================================================
CREATE TABLE promotions (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    service_id      uuid NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    name            text NOT NULL,
    discount_type   text NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value  integer NOT NULL CHECK (discount_value >= 0),
    starts_at       timestamptz NOT NULL,
    ends_at         timestamptz NOT NULL,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CHECK (starts_at < ends_at)
);

CREATE INDEX idx_promotions_tenant_service ON promotions(tenant_id, service_id);

-- =========================================================================
-- Row-Level Security
-- =========================================================================
-- O backend deve executar, no início de cada transação:
--   SET LOCAL app.tenant_id = '<uuid-do-tenant-resolvido>';

ALTER TABLE tenants                ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_branding        ENABLE ROW LEVEL SECURITY;
ALTER TABLE professionals          ENABLE ROW LEVEL SECURITY;
ALTER TABLE services               ENABLE ROW LEVEL SECURITY;
ALTER TABLE professional_services  ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_hours         ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_slots          ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients                ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments           ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions             ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON tenants
    USING (id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY tenant_isolation ON tenant_branding
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY tenant_isolation ON professionals
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY tenant_isolation ON services
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY tenant_isolation ON professional_services
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY tenant_isolation ON business_hours
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY tenant_isolation ON blocked_slots
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY tenant_isolation ON clients
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY tenant_isolation ON appointments
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY tenant_isolation ON promotions
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
