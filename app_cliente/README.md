# Agenda360 — App Cliente

App Flutter do cliente final da Carioca Barbearia — fluxo de agendamento
sem cadastro/senha, conforme
[`docs/REQUIREMENTS.md`](../docs/REQUIREMENTS.md) §1. Consome a API em
[`backend/`](../backend/README.md).

## Rodando localmente

Este diretório tem só o código Dart (`lib/`) e o `pubspec.yaml` — as
pastas nativas (`android/`, `ios/`, `web/`) ainda não foram geradas
(precisam do SDK do Flutter, que não estava disponível no ambiente onde
este app foi escrito).

1. Gerar as pastas de plataforma (não sobrescreve `lib/`/`pubspec.yaml` já
   existentes):

   ```bash
   flutter create --org com.agenda360 .
   ```

2. Instalar as dependências:

   ```bash
   flutter pub get
   ```

3. Com o backend rodando (ver [`backend/README.md`](../backend/README.md)
   — `docker compose up`, `alembic upgrade head`, `python -m app.seed`),
   aponte o app pra API. Por padrão usa `http://localhost:8000`
   (`lib/config.dart`); para mudar sem editar código:

   ```bash
   flutter run --dart-define=AGENDA360_API_BASE_URL=http://10.0.2.2:8000
   ```

   (`10.0.2.2` é o endereço do host visto de dentro do emulador Android;
   no Chrome/desktop/iOS simulator, `localhost` já funciona.)

4. `flutter run`. Teste o fluxo completo: Home → nome/telefone → serviço
   → profissional (Anderson) → horário → confirmar → sucesso, e depois
   cancelar pela tela "Meus agendamentos".

5. `flutter analyze` — o código foi escrito e revisado à mão (sem o SDK
   disponível para compilar), então essa é a primeira verificação real de
   tipos/sintaxe que ele vai passar.

## Decisões desta etapa

Ver a seção "Decisões desta etapa" do plano de implementação original,
ou resumidamente:

- **Tenant fixo** (`lib/config.dart`): só existe a Carioca Barbearia na
  v1, então `tenantSlug` é uma constante — não build flavors nem config
  remota (decisão em aberto em `docs/ARCHITECTURE.md` §7, só relevante
  quando existir um segundo tenant).
- **Estado**: um único `ChangeNotifier` (`BookingController`,
  `lib/state/`) via `provider`, guardando as escolhas do wizard.
- **"Meus agendamentos"**: guardado localmente no aparelho
  (`shared_preferences`, `lib/services/appointment_store.dart`) — o
  backend não tem "listar por telefone" (não é requisito do MVP, que não
  tem login). Cancelar continua chamando a API de verdade.

## Estrutura

```
lib/
├── main.dart                  # Provider + MaterialApp
├── config.dart                 # tenantSlug, apiBaseUrl
├── theme/app_theme.dart         # paleta Flamengo
├── models/                       # Service, Professional, TenantBranding, Appointment, SavedAppointment
├── services/                      # ApiClient (http), AgendaApi (endpoints), AppointmentStore (local)
├── state/booking_controller.dart   # estado do wizard
├── widgets/future_loader.dart       # loading/erro/retry reutilizável
└── screens/                          # as 7 telas do fluxo + Meus Agendamentos
```
