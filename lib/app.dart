import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/core/theme/app_theme.dart';
import 'package:moto_amg/features/onboarding/presentation/widgets/app_bootstrap.dart';
import 'package:moto_amg/features/navigation/presentation/providers/navigation_providers.dart';

class MotoAmgApp extends StatelessWidget {
  const MotoAmgApp({super.key, this.overrides = const []});

  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: const _MotoAmgRoot(),
    );
  }
}

class _MotoAmgRoot extends ConsumerWidget {
  const _MotoAmgRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(androidGraphicsCompatProvider);
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
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AppBootstrap(),
    );
  }
}
