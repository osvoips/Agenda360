/// Configuração do build White Label deste app.
///
/// Mesma decisão do app_cliente (ver lib/config.dart lá): v1 tem um único
/// tenant, então isso é uma constante em vez de build flavors/config
/// remota — revisitar em docs/ARCHITECTURE.md §7 quando existir o segundo
/// tenant.
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
