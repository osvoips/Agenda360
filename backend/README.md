# Agenda360 — Backend

API FastAPI multi-tenant do Agenda360. Ver
[`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md),
[`docs/REQUIREMENTS.md`](../docs/REQUIREMENTS.md) e
[`docs/DATABASE.md`](../docs/DATABASE.md) para o contexto completo.

## Rodando localmente

1. Subir o Postgres:

   ```bash
   docker compose -f ../docker/docker-compose.yml up -d db
   ```

2. Instalar as dependências (num virtualenv):

   ```bash
   python3 -m venv .venv && source .venv/bin/activate
   pip install -e ".[dev]"
   ```

3. Copiar as variáveis de ambiente:

   ```bash
   cp .env.example .env
   ```

4. Rodar as migrations (cria as tabelas, RLS policies e a role `agenda360_app`):

   ```bash
   alembic upgrade head
   ```

5. Popular o tenant piloto (Carioca Barbearia, Anderson, serviços, horários, admin):

   ```bash
   python -m app.seed
   ```

   Isso imprime o login do admin (`admin@cariocabarbearia.com.br` / senha
   de desenvolvimento) — troque antes de qualquer deploy real.

6. Subir a API:

   ```bash
   uvicorn app.main:app --reload
   ```

7. Abrir `http://localhost:8000/docs` (Swagger UI). Rotas de cliente
   exigem o header `X-Tenant-Slug: carioca-barbearia`. Rotas de
   barbearia/admin exigem `Authorization: Bearer <token>` — pegue o token
   em `POST /v1/auth/login`.

Alternativa: `docker compose -f ../docker/docker-compose.yml up --build`
sobe banco + API juntos e já roda as migrations sozinho ao iniciar; só falta
popular o tenant piloto na primeira vez: `docker compose exec api python -m
app.seed`.

## Testes

Precisam do Postgres do compose no ar (criam e derrubam sozinhos um banco
`agenda360_test` à parte do banco de desenvolvimento):

```bash
pytest
```

## Estrutura

Ver o plano de implementação original ou `docs/ARCHITECTURE.md` §6 para a
visão geral de pastas. Resumo:

- `app/core/` — configuração, sessão de banco (com o `SET LOCAL` de RLS),
  resolução de tenant, segurança (hash de senha, JWT)
- `app/models/` — SQLAlchemy ORM, espelha `database/schema.sql`
- `app/schemas/` — Pydantic (request/response)
- `app/api/` — routers (`client_routes`, `auth_routes`,
  `barbershop_routes`, `admin_routes`)
- `app/services/` — regras de negócio (disponibilidade, agenda)
- `alembic/` — migrations (fonte de verdade executável; `database/schema.sql` é a referência legível)
- `tests/` — pytest + httpx, contra Postgres real
