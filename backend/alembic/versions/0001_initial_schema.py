"""Initial schema

Revision ID: 0001
Revises:
Create Date: 2026-07-25

O DDL abaixo é o mesmo de database/schema.sql (fonte da verdade legível por
humanos — ver docs/DATABASE.md). Mantenha os dois em sincronia manualmente:
o autogenerate do Alembic não modela RLS policies nem EXCLUDE USING gist.
"""
from typing import Sequence, Union

from alembic import op

from app.core.config import get_settings

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Senha vem de APP_DB_PASSWORD (settings.app_db_password) em vez de fixa no
# código — em produção (Railway) é gerada/forte; em dev cai no default
# 'agenda360_app' que bate com o .env.example. Escapa aspas simples pra
# evitar quebrar o literal SQL caso a senha gerada contenha uma.
_APP_DB_PASSWORD = get_settings().app_db_password.replace("'", "''")

UPGRADE_SQL = f"""
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

CREATE TABLE tenants (
    id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug                      text NOT NULL UNIQUE,
    name                      text NOT NULL,
    segment                   text NOT NULL DEFAULT 'barbershop',
    min_cancel_notice_minutes integer NOT NULL DEFAULT 120,
    is_active                 boolean NOT NULL DEFAULT true,
    created_at                timestamptz NOT NULL DEFAULT now(),
    updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE tenant_branding (
    tenant_id       uuid PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
    display_name    text NOT NULL,
    logo_url        text,
    icon_url        text,
    primary_color   text,
    secondary_color text
);

CREATE TABLE staff_users (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id      uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name           text NOT NULL,
    email          text NOT NULL,
    password_hash  text NOT NULL,
    role           text NOT NULL CHECK (role IN ('staff', 'admin')),
    is_active      boolean NOT NULL DEFAULT true,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_staff_users_tenant_email UNIQUE (tenant_id, email)
);

CREATE INDEX idx_staff_users_tenant ON staff_users(tenant_id);

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

CREATE TABLE professional_services (
    tenant_id        uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    professional_id  uuid NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    service_id       uuid NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    PRIMARY KEY (professional_id, service_id)
);

CREATE INDEX idx_professional_services_tenant ON professional_services(tenant_id);

CREATE TABLE business_hours (
    tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    weekday     smallint NOT NULL CHECK (weekday BETWEEN 0 AND 6),
    opens_at    time,
    closes_at   time,
    is_closed   boolean NOT NULL DEFAULT false,
    PRIMARY KEY (tenant_id, weekday),
    CHECK (is_closed OR (opens_at IS NOT NULL AND closes_at IS NOT NULL AND opens_at < closes_at))
);

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

CREATE TABLE clients (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name        text NOT NULL,
    phone       text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_clients_tenant_phone UNIQUE (tenant_id, phone)
);

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
    EXCLUDE USING gist (
        professional_id WITH =,
        tstzrange(starts_at, ends_at) WITH &&
    ) WHERE (status <> 'cancelled')
);

CREATE INDEX idx_appointments_tenant_professional_starts
    ON appointments(tenant_id, professional_id, starts_at);
CREATE INDEX idx_appointments_tenant_client
    ON appointments(tenant_id, client_id);

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

ALTER TABLE tenants                ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_branding        ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE professionals          ENABLE ROW LEVEL SECURITY;
ALTER TABLE services               ENABLE ROW LEVEL SECURITY;
ALTER TABLE professional_services  ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_hours         ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_slots          ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients                ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments           ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions             ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_read ON tenants
    FOR SELECT USING (true);
CREATE POLICY tenant_update ON tenants
    FOR UPDATE USING (id = current_setting('app.tenant_id', true)::uuid);

CREATE POLICY tenant_isolation ON tenant_branding
    USING (tenant_id = current_setting('app.tenant_id', true)::uuid);
CREATE POLICY tenant_isolation ON staff_users
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

DO $do$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'agenda360_app') THEN
        CREATE ROLE agenda360_app LOGIN PASSWORD '{_APP_DB_PASSWORD}';
    ELSE
        ALTER ROLE agenda360_app WITH PASSWORD '{_APP_DB_PASSWORD}';
    END IF;
END
$do$;

GRANT USAGE ON SCHEMA public TO agenda360_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO agenda360_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO agenda360_app;
"""

DOWNGRADE_SQL = """
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM agenda360_app;
REVOKE USAGE ON SCHEMA public FROM agenda360_app;
DROP ROLE IF EXISTS agenda360_app;

DROP TABLE IF EXISTS promotions CASCADE;
DROP TABLE IF EXISTS appointments CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS blocked_slots CASCADE;
DROP TABLE IF EXISTS business_hours CASCADE;
DROP TABLE IF EXISTS professional_services CASCADE;
DROP TABLE IF EXISTS services CASCADE;
DROP TABLE IF EXISTS professionals CASCADE;
DROP TABLE IF EXISTS staff_users CASCADE;
DROP TABLE IF EXISTS tenant_branding CASCADE;
DROP TABLE IF EXISTS tenants CASCADE;
"""


def upgrade() -> None:
    op.execute(UPGRADE_SQL)


def downgrade() -> None:
    op.execute(DOWNGRADE_SQL)
