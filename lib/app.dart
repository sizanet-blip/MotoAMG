import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/core/theme/app_theme.dart';
import 'package:loc_motos/core/theme/app_color_theme_provider.dart';
import 'package:loc_motos/features/auth/presentation/widgets/auth_gate.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';

class LocMotosApp extends StatelessWidget {
  const LocMotosApp({super.key, this.overrides = const []});

  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: const _LocMotosRoot(),
    );
  }
}

class _LocMotosRoot extends ConsumerWidget {
  const _LocMotosRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(androidGraphicsCompatProvider);
    final palette = ref.watch(appColorThemeProvider);
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
