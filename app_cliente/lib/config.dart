/// Configuração do build White Label deste app.
///
/// Na v1 existe um único tenant (Carioca Barbearia), então isso é uma
/// constante em vez de build flavors ou config remota — decisão em aberto
/// em docs/ARCHITECTURE.md §7, revisitar quando existir o segundo tenant.
class AppConfig {
  AppConfig._();

  static const String tenantSlug = 'carioca-barbearia';

  /// Ajuste para o endereço da API antes de rodar:
  /// - Emulador Android: http://10.0.2.2:8000
  /// - iOS simulator / Chrome / desktop: http://localhost:8000
  static const String apiBaseUrl = String.fromEnvironment(
    'AGENDA360_API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
