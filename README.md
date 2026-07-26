# Agenda360

Plataforma **White Label** de agendamento para pequenos negócios, começando
por barbearias. Cada cliente recebe um aplicativo com a própria marca — o
Agenda360 roda por trás, invisível ao usuário final.

> **Cliente piloto:** 💈 Carioca Barbearia — primeiro app real, usado para
> validar o produto em ambiente de uso cotidiano.

## Sobre o projeto

A **Agenda360 Tecnologia** desenvolve aplicativos personalizados de
agendamento para prestadores de serviço. O produto não é "um app para uma
barbearia" — é uma plataforma multi-tenant desenhada para vender o mesmo
sistema, com marcas diferentes, para vários negócios ao mesmo tempo.

```
Agenda360
│
├── Carioca Barbearia
├── Barbearia Elite
├── Barbearia Central
├── Barbearia Premium
└── ...
```

Cada tenant tem: aplicativo próprio, logo própria, ícone próprio, nome
próprio — todos rodando sobre a mesma base de código e infraestrutura. Ver
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) para o detalhamento técnico de
como isso é implementado.

### Diferencial

Agendamento extremamente simples: o cliente final agenda um horário em
**menos de 30 segundos**, sem cadastro e sem senha.

### Público inicial e expansão

Começa em barbearias. Expansão planejada para: salões de beleza, clínicas
de estética, personal trainers, pet shops, consultórios e outros
prestadores de serviço — sem reescrever a plataforma.

## Escopo do MVP

**Cliente** (sem cadastro/senha):
- Informar nome e telefone
- Escolher serviço, barbeiro e horário
- Confirmar agendamento
- Cancelar dentro do prazo permitido

**Barbearia:**
- Agenda do dia e semanal
- Confirmar presença / cancelar atendimento
- Bloquear horários
- Configurar dias e horários de funcionamento

**Administrador:**
- Cadastro de barbeiros, serviços, horários e promoções
- Visualização da agenda completa

Primeiro barbeiro cadastrado: **Anderson** — mas o sistema é preparado para
múltiplos profissionais desde o início.

### Serviços (v1)

| Serviço | Tempo |
|---|---|
| Corte Masculino | 45 min |
| Barba | 30 min |
| Corte + Barba | 70 min |
| Pigmentação | a definir |
| Sobrancelha | a definir |

### Pagamento

Na v1, o pagamento é feito presencialmente na barbearia. PIX, cartão e
pagamento pelo aplicativo ficam para versões futuras.

## Design

Inspirado nas cores do Flamengo — preto, vermelho e branco. Visual moderno,
premium e simples.

## Plataforma

- 📱 Aplicativo do Cliente
- 💻 Painel Administrativo
- 🌐 Versão Web
- 🗄️ Banco de Dados
- 🔔 Notificações
- 🤖 IA (futuramente)

## Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| App Cliente / Painel Admin | Flutter (Android, iOS, Web) |
| Backend | FastAPI (Python) |
| Banco de Dados | PostgreSQL |
| ORM / Migrations | SQLAlchemy 2.0 (async) + Alembic |
| Infraestrutura | Docker |
| Controle de versão | GitHub |

Detalhes e justificativas de cada escolha em
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Estrutura do repositório

```
agenda360/
├── docs/                # documentação técnica (arquitetura, requisitos, roadmap)
├── backend/              # API FastAPI (Python)
├── app_cliente/          # Flutter — app do cliente final
├── app_admin/            # Flutter — painel administrativo
├── database/             # migrations, scripts, modelagem
├── docker/                # Dockerfiles, docker-compose
└── README.md
```

## Documentação

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — arquitetura multi-tenant,
  modelo de domínio, stack e decisões técnicas
- [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) — requisitos funcionais e não
  funcionais do MVP
- [docs/ROADMAP.md](docs/ROADMAP.md) — fases do produto, do MVP à expansão
  de segmentos e IA
- [docs/DATABASE.md](docs/DATABASE.md) — modelagem do banco de dados
  (entidades, relacionamentos, RLS) e [`database/schema.sql`](database/schema.sql)
- [docs/prototypes/screens.html](docs/prototypes/screens.html) — protótipo
  navegável do App Cliente, Painel da Barbearia e Painel Administrador
  (abrir no navegador)
- [backend/README.md](backend/README.md) — como rodar a API localmente
- [app_cliente/README.md](app_cliente/README.md) — como rodar o app do
  cliente localmente
- [app_admin/README.md](app_admin/README.md) — como rodar o painel da
  barbearia/administrador localmente

## Status

**Fase 1 (MVP) completa no código**: backend (FastAPI), App Cliente
(Flutter) e Painel da Barbearia/Administrador (Flutter) — os três
pedaços previstos em `docs/ROADMAP.md` estão implementados, cobrindo
todos os requisitos de `docs/REQUIREMENTS.md`. Nada disso foi executado
de verdade ainda: este ambiente não tinha Docker nem SDK do Flutter
disponíveis, então tudo foi escrito e revisado manualmente (imports,
nomes de campo e assinaturas de método cruzados à mão entre os arquivos),
sem `pytest`, `flutter analyze` ou `flutter run`. Antes de considerar a
Fase 1 validada de verdade, alguém precisa rodar os três READMEs
(`backend/`, `app_cliente/`, `app_admin/`) numa máquina com Docker e
Flutter instalados.
