# Roadmap — Agenda360

Fases de evolução do produto. Cada fase entrega valor de forma incremental,
sem exigir reescrita das fases anteriores — condição arquitetural definida
em [ARCHITECTURE.md](ARCHITECTURE.md).

## Fase 0 — Fundação (atual)

Planejamento e documentação técnica antes de qualquer código.

- [x] Definição de missão, modelo de negócio e público-alvo.
- [x] Repositório oficial criado (`git init`, local).
- [x] `README.md`, `ARCHITECTURE.md`, `REQUIREMENTS.md`, `ROADMAP.md`.
- [x] Modelagem do banco de dados (schema multi-tenant, entidades §4 de
      ARCHITECTURE.md) — ver [DATABASE.md](DATABASE.md) e
      [`database/schema.sql`](../database/schema.sql).
- [x] Protótipos de tela (app cliente + painel admin) — ver
      [`docs/prototypes/screens.html`](prototypes/screens.html) (abrir no
      navegador).
- [ ] Decisões técnicas restantes: verificação de telefone, resolução de
      tenant no Flutter (build flavor vs. runtime config).

## Fase 1 — MVP com Carioca Barbearia

Objetivo: validar o produto em uso real com o cliente piloto.

- Backend FastAPI com autenticação por tenant e RLS no PostgreSQL.
- App Cliente (Flutter): fluxo completo de agendamento sem cadastro,
  conforme `REQUIREMENTS.md` §1.
- Painel da Barbearia: agenda do dia/semana, confirmação/cancelamento,
  bloqueio de horários.
- Painel Administrativo: cadastro de barbeiros, serviços, horários,
  promoções.
- White Label aplicado apenas ao tenant Carioca Barbearia (1 build).
- Pagamento presencial (fora do app).
- **Critério de saída:** Carioca Barbearia usando o app no dia a dia por
  tempo suficiente para validar o fluxo de agendamento e coletar feedback
  real de uso.

## Fase 2 — Pagamento e Notificações

- Integração de pagamento via PIX.
- Integração de pagamento via cartão.
- Pagamento diretamente pelo aplicativo (fechamento do ciclo de compra).
- Notificações push de confirmação e lembrete de agendamento.
- Verificação de telefone (SMS/WhatsApp), se validado como necessário
  após a Fase 1.

## Fase 3 — Multi-Tenant Comercial

Transformar o sistema validado com 1 cliente em produto vendável para N
clientes.

- Processo de onboarding de novos tenants (criação de tenant, branding,
  cadastro inicial de serviços/profissionais).
- Suporte a múltiplos builds White Label em paralelo (ou runtime config,
  conforme decisão técnica pendente).
- Painel administrativo interno da Agenda360 Tecnologia (gestão de
  tenants, não visível aos clientes finais).
- Modelo de cobrança dos tenants definido e operacional.
- **Meta:** onboarding de barbearias adicionais além da Carioca Barbearia.

## Fase 4 — Expansão de Segmentos

Sem alterações estruturais na plataforma — apenas configuração de novos
tipos de negócio, graças ao modelo de domínio genérico (RNF-06).

- Salões de Beleza
- Clínicas de Estética
- Personal Trainers
- Pet Shops
- Consultórios
- Outros prestadores de serviço

## Fase 5 — Inteligência Artificial

- Sugestão inteligente de horários (otimização de agenda).
- Previsão de no-show.
- Chatbot de atendimento para dúvidas e agendamento assistido.

## Fora de Fase / Contínuo

Atividades que atravessam todas as fases:

- Testes (unitários, integração, e2e nos fluxos críticos de agendamento).
- Documentação técnica mantida atualizada.
- Publicação incremental (App Store / Play Store / Web) conforme cada
  tenant entra em produção.
