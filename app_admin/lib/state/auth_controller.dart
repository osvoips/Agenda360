import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/admin_api.dart';
import '../services/api_client.dart';

/// Sessão de quem está logado (staff ou admin) — persistida localmente
/// para não pedir login toda vez que o app abrir. Também é dono do
/// [ApiClient]/[AdminApi] usados pelo resto do app, para manter o token
/// de autenticação sempre em sincronia com a sessão.
class AuthController extends ChangeNotifier {
  AuthController() {
    _restoreSession();
  }

  static const _tokenKey = 'agenda360_admin.token';
  static const _roleKey = 'agenda360_admin.role';
  static const _emailKey = 'agenda360_admin.email';

  final ApiClient _apiClient = ApiClient();
  late final AdminApi api = AdminApi(_apiClient);

  bool _loading = true;
  String? _token;
  String? _role;
  String? _email;

  bool get isLoading => _loading;
  bool get isAuthenticated => _token != null;
  bool get isAdmin => _role == 'admin';
  String? get email => _email;
  String? get role => _role;

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _role = prefs.getString(_roleKey);
    _email = prefs.getString(_emailKey);
    _apiClient.authToken = _token;
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await api.login(email: email, password: password);
    _token = result.accessToken;
    _role = result.role;
    _email = email;
    _apiClient.authToken = _token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_roleKey, _role!);
    await prefs.setString(_emailKey, _email!);

    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _email = null;
    _apiClient.authToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_emailKey);

    notifyListeners();
  }
}
