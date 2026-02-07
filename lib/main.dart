import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dp/dp_dashboard.dart';
import 'screens/formateur/formateur_dashboard.dart';
import 'screens/stagiaire/stagiaire_dashboard.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/user.dart';

import 'providers/notification_provider.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR', null);
    
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  } catch (e) {
    debugPrint('Critical initialization error: $e');
  }

  final authService = AuthService();
  
  try {
    await authService.checkSession();
  } catch (e) {
    debugPrint('Session check error during startup: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const AcademicProApp(),
    ),
  );
}

class AcademicProApp extends StatelessWidget {
  const AcademicProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academic Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Consumer<AuthService>(
        builder: (context, authService, child) {
          if (authService.isLoggedIn) {
            return _getDashboardForRole(authService.currentUser?.role);
          }
          return const LoginScreen();
        },
      ),
    );
  }

  Widget _getDashboardForRole(UserRole? role) {
    switch (role) {
      case UserRole.dp:
        return const DPDashboard();
      case UserRole.formateur:
        return const FormateurDashboard();
      case UserRole.stagiaire:
        return const StagiaireDashboard();
      default:
        return const LoginScreen();
    }
  }
}

