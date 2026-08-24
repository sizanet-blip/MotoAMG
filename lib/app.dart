import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/core/theme/app_theme.dart';
import 'package:loc_motos/features/auth/presentation/widgets/auth_gate.dart';

class LocMotosApp extends StatelessWidget {
  const LocMotosApp({super.key, this.overrides = const []});

  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const AuthGate(),
      ),
    );
  }
}
