import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/admin_shell.dart';
import 'screens/login_screen.dart';
import 'state/auth_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(const Agenda360AdminApp());
}

class Agenda360AdminApp extends StatelessWidget {
  const Agenda360AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController(),
      child: MaterialApp(
        title: 'Agenda360 — Painel',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const AuthGate(),
      ),
    );
  }
}

/// Decide entre login e o painel conforme a sessão persistida —
/// AuthController tenta restaurar do shared_preferences ao ser criado.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isAuthenticated ? const AdminShell() : const LoginScreen();
  }
}
