# Arquitetura — Agenda360

## 1. Visão Geral

O Agenda360 é uma **plataforma multi-tenant White Label** de agendamento para
prestadores de serviço, começando por barbearias. Cada cliente (tenant) —
ex.: Carioca Barbearia — recebe um aplicativo com sua própria marca (logo,
cores, nome, ícone), mas todo o sistema roda sobre a **mesma base de código e
a mesma infraestrutura**.

O objetivo arquitetural central é: **nenhuma decisão de design deve amarrar o
sistema a "barbearia"**. O domínio de negócio (barbearia, serviços,
barbeiros) é uma configuração de um domínio genérico maior (negócio,
serviços, profissionais), permitindo expandir para salões, clínicas de
estética, personal trainers, pet shops etc. sem reescrever a plataforma.

## 2. Estratégia Multi-Tenant

### 2.1 Isolamento de dados: single database, shared schema

Para o estágio atual (1 cliente piloto, poucos tenants nos próximos anos),
a abordagem recomendada é:

- **Um único banco PostgreSQL**, compartilhado entre todos os tenants.
- Toda tabela de domínio carrega uma coluna `tenant_id` (FK para a tabela
  `tenants`).
- Isolamento lógico garantido na camada de aplicação (todo query filtra por
  `tenant_id`) e reforçado no banco via **Row-Level Security (RLS)** do
  PostgreSQL como rede de segurança.

Motivo da escolha: com o volume esperado no curto/médio prazo, "database por
tenant" ou "schema por tenant" adicionam complexidade operacional (migrations
N vezes, backups N vezes) sem benefício real ainda. Se um cliente grande
exigir isolamento físico total no futuro, o modelo permite migrar esse tenant
específico para um banco dedicado sem alterar o desenho da aplicação.

### 2.2 Identificação do tenant

Cada aplicativo White Label é compilado/configurado apontando para um
`tenant_id` (ou `tenant_slug`) fixo, definido em tempo de build ou via
configuração remota. O app do cliente final nunca escolhe o tenant — ele
*é* o tenant.

Fluxo de resolução do tenant por camada:

- **App do cliente (Flutter, White Label):** `tenant_slug` embutido na
  configuração do build (flavor/variant específico da barbearia).
- **Painel administrativo / Web:** `tenant_slug` resolvido por subdomínio
  (`cariocabarbearia.agenda360.app`) ou login vinculado a um tenant.
- **Backend:** todo request autenticado carrega `tenant_id` no token; todo
  request público (ex.: cliente agendando) resolve o tenant pela origem
  (subdomínio, app id, ou parâmetro explícito) e valida no primeiro
  middleware da requisição.

### 2.3 Personalização White Label

Tabela `tenant_branding` (ou campos em `tenants`) guarda: nome exibido, logo,
paleta de cores, ícone do app. O app cliente consome essas configurações via
API na inicialização (ou embutidas no build, na v1). Nenhuma referência à
marca "Agenda360" aparece nas telas do app do cliente final.

## 3. Componentes da Plataforma

```
┌─────────────────────┐   ┌──────────────────────┐
│  App Cliente (Flutter)│   │ Painel Admin (Flutter/Web) │
│  White Label por tenant│   │ multi-tenant (login)  │
└──────────┬───────────┘   └───────────┬───────────┘
           │                            │
           └────────────┬───────────────┘
                         │ HTTPS / REST-JSON
                ┌────────▼─────────┐
                │   Backend API     │
                │ (ASP.NET Core ou  │
                │     FastAPI)      │
                └────────┬─────────┘
                         │
          ┌──────────────┼───────────────┐
          │              │               │
   ┌──────▼─────┐ ┌──────▼──────┐ ┌──────▼──────┐
   │ PostgreSQL │ │ Notificações │ │  IA (futuro) │
   │ (multi-tenant)│ (push/SMS) │ │              │
   └────────────┘ └─────────────┘ └─────────────┘
```

- **App do Cliente (Flutter):** fluxo de agendamento sem cadastro/senha
  (nome + telefone), Android/iOS/Web via mesmo código-base.
- **Painel Administrativo (Flutter Web ou Web dedicado):** usado pela
  barbearia/admin para gerenciar agenda, barbeiros, serviços, horários.
- **Backend API:** único backend multi-tenant, stateless, atrás de
  autenticação por papel (cliente anônimo com token curto de sessão de
  agendamento; barbearia/admin com login).
- **Banco de Dados (PostgreSQL):** shared schema com `tenant_id`, conforme
  §2.1.
- **Notificações:** push (app) e futuramente SMS/WhatsApp, para confirmação e
  lembrete de agendamento.
- **IA (futuro):** sugestão de horários, previsão de no-show, chatbot de
  atendimento — módulo desacoplado, não bloqueia o MVP.

## 4. Modelo de Domínio (alto nível)

Entidades centrais, já pensadas para múltiplos segmentos além de barbearia:

- `tenant` — o negócio (ex.: Carioca Barbearia). Dono de tudo abaixo.
- `professional` — o prestador (barbeiro, cabeleireiro, esteticista...).
  Chamado de "barbeiro" na UI da v1, mas modelado como papel genérico.
- `service` — serviço oferecido, com duração e (futuramente) preço.
- `business_hours` — dias/horários de funcionamento do tenant.
- `professional_availability` / `blocked_slot` — bloqueios de agenda por
  profissional.
- `appointment` — o agendamento em si: tenant, cliente (nome+telefone),
  profissional, serviço, horário, status (confirmado, cancelado,
  concluído).
- `client` — identificado por telefone dentro do tenant (sem senha/login),
  reaproveitado entre agendamentos futuros pelo mesmo número.
- `promotion` — regras promocionais por tenant/serviço (v1 simples: só
  cadastro, sem motor de regras complexo).

Esse modelo já comporta "Salão de Beleza" ou "Clínica de Estética" trocando
apenas o conteúdo de `service` e o rótulo de `professional`, sem mudança de
schema.

## 5. Escolhas Tecnológicas

| Camada | Escolha | Observação |
|---|---|---|
| App Cliente / Painel | Flutter | Um código-base para Android, iOS e Web |
| Backend | **FastAPI** | Ver §5.1 |
| Banco de Dados | PostgreSQL | Shared schema multi-tenant |
| ORM / Migrations | SQLAlchemy 2.0 (async) + Alembic | Suporte a `asyncpg`, integra bem com RLS por `tenant_id` |
| Infraestrutura | Docker | Empacotamento e ambientes reprodutíveis |
| Controle de versão | GitHub | Monorepo (ver §6) |

### 5.1 Backend: FastAPI (decidido)

Decisão: **FastAPI**, em vez de ASP.NET Core. Motivos:

- **IA no roadmap:** o Agenda360 já prevê módulo de IA (sugestão de
  horários, previsão de no-show, chatbot de atendimento). O ecossistema
  Python (FastAPI + libs de ML/LLM) reduz o atrito para integrar isso mais
  tarde, sem precisar de uma stack paralela.
- **Velocidade de desenvolvimento do MVP:** Pydantic dá validação de dados
  "de graça" (importante em multi-tenant, onde todo payload carrega
  `tenant_id`), e a documentação OpenAPI é gerada automaticamente —
  útil para os apps Flutter consumirem a API desde cedo.
- **Suporte assíncrono maduro:** `asyncpg`/SQLAlchemy 2.0 async lidam bem
  com PostgreSQL e RLS, sem a curva de aprendizado adicional do EF Core.
- **Equipe pequena / software house enxuta:** Python tende a ter setup e
  onboarding mais rápidos que .NET para esse estágio do projeto.

ASP.NET Core seguiria como alternativa se, no futuro, o produto precisar de
características tipicamente corporativas (ex.: integração pesada com stacks
.NET de um cliente enterprise) — não é o caso do Agenda360 hoje.

## 6. Organização do Repositório (proposta)

Monorepo, para manter documentação, backend, apps e infra sincronizados
desde o início:

```
agenda360/
├── docs/                # este documento, requisitos, roadmap
├── backend/             # API FastAPI (Python)
├── app_cliente/          # Flutter — app do cliente final
├── app_admin/             # Flutter — painel administrativo
├── database/             # migrations, scripts, modelagem
├── docker/               # Dockerfiles, docker-compose
└── README.md
```

## 7. Decisões em Aberto

- [x] Backend: **FastAPI** (§5.1).
- [ ] Autenticação do cliente final: token de sessão por telefone (com
      verificação via SMS/WhatsApp?) ou apenas nome+telefone sem
      verificação na v1 (mais simples, risco de dados falsos).
- [ ] Estratégia de resolução de tenant no app Flutter: build flavors
      (1 build por cliente) vs. runtime config (1 build, config remota).
- [ ] Estrutura de cobrança do modelo White Label (mensalidade por tenant,
      setup fee, etc.) — fora do escopo técnico, mas impacta cadastro de
      tenants.
