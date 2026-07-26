# Agenda360 — Painel da Barbearia/Administrador

Um único app Flutter para os dois papéis operacionais do MVP — `staff`
(agenda do dia a dia) e `admin` (cadastro) — conforme
[`docs/REQUIREMENTS.md`](../docs/REQUIREMENTS.md) §§2-3. Consome a API em
[`backend/`](../backend/README.md).

## Rodando localmente

Mesma situação do `app_cliente`: só o código Dart (`lib/`) e o
`pubspec.yaml` existem aqui — as pastas nativas ainda não foram geradas
(sem SDK do Flutter disponível no ambiente onde este app foi escrito).

1. Gerar as pastas de plataforma:

   ```bash
   flutter create --org com.agenda360 .
   ```

2. `flutter pub get`

3. Com o backend rodando e o seed aplicado (`backend/README.md`), rode:

   ```bash
   flutter run --dart-define=AGENDA360_API_BASE_URL=http://localhost:8000
   ```

   (`http://10.0.2.2:8000` no emulador Android.)

4. Login com as credenciais impressas por `python -m app.seed`
   (`admin@cariocabarbearia.com.br` / senha de desenvolvimento — role
   `admin`, então você vê o menu completo).

5. Testar: ver a agenda do dia (deve aparecer qualquer agendamento feito
   pelo `app_cliente`) → confirmar/cancelar → bloquear um horário →
   ajustar horário de funcionamento → cadastrar um profissional/serviço/
   promoção.

6. `flutter analyze` — mesmo aviso do `app_cliente`: o código foi escrito
   e revisado à mão (imports, nomes de campo e assinaturas de método
   cruzados manualmente entre todos os arquivos), sem o SDK disponível
   para compilar de verdade.

## Decisões e limitações conhecidas desta etapa

- **Um app, dois papéis**: `AdminShell` (`lib/screens/admin_shell.dart`)
  mostra Agenda + Horário de funcionamento pra `staff`, e mais
  Profissionais/Serviços/Promoções pra `admin`.
- **Endpoint novo no backend**: `GET /v1/barbershop/professionals`
  (`staff` e `admin`) foi adicionado para o formulário de bloqueio de
  horário poder listar profissionais — `staff` não tinha antes como
  saber os IDs (só existia via `/v1/admin/professionals`, admin only).
- **Reatribuir serviços de um profissional existente não está nesta
  versão**: `ProfessionalOut` não devolve `service_ids`, então editar um
  profissional só altera nome/telefone/ativo. A associação com serviços
  só é definida na criação. Reatribuir depois fica para uma iteração
  futura (precisaria de um endpoint que devolva os `service_ids` atuais).
- **Seletor de hora em inglês**: `showTimePicker`/`showDatePicker` do
  Flutter aparecem em inglês (sem o pacote `flutter_localizations`
  configurado, mesma decisão do `app_cliente`) — cosmético, não afeta a
  funcionalidade.
- **Não há tela para ver/remover bloqueios já criados** — só criar
  (`POST .../blocked-slots`). O endpoint de remoção
  (`DELETE .../blocked-slots/{id}`) já existe no backend e no
  `AdminApi.deleteBlockedSlot`, só falta a tela de listagem.

## Estrutura

```
lib/
├── main.dart                    # Provider<AuthController> + MaterialApp + AuthGate
├── config.dart                   # tenantSlug, apiBaseUrl
├── theme/app_theme.dart           # mesma paleta Flamengo do app_cliente
├── models/                          # AgendaAppointment, Professional, Service, Promotion, BusinessHoursDay
├── services/
│   ├── api_client.dart               # http + Authorization: Bearer <token>
│   └── admin_api.dart                  # login, agenda, confirm/cancel, bloqueios, horários, CRUDs
├── state/auth_controller.dart          # sessão (token/role/e-mail), persistida, dona do ApiClient/AdminApi
├── widgets/                              # FutureLoader, StatusBadge
└── screens/
    ├── login_screen.dart
    ├── admin_shell.dart                    # Drawer condicional por role
    ├── agenda_screen.dart                   # abas Dia/Semana, confirmar/cancelar, bloquear horário
    ├── business_hours_screen.dart
    ├── professionals_screen.dart             # admin only
    ├── services_screen.dart                   # admin only
    └── promotions_screen.dart                  # admin only
```
