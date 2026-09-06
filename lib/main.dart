import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:moto_amg/app.dart';
import 'package:moto_amg/firebase_options.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // MapLibre + Virtual Display (GLSurfaceView) se cae en emuladores/API antiguas.
  // TextureView / hybrid composition es más estable en Android.
  if (!kIsWeb && Platform.isAndroid) {
    MapLibreMap.useHybridComposition = true;
  }
  await Hive.initFlutter();
  await _initializeFirebase();
  runApp(const MotoAmgApp());
}

Future<void> _initializeFirebase() async {
  if (!DefaultFirebaseOptions.isConfigured) {
    debugPrint(
      'Firebase no configurado. Ejecuta:\n'
      '  dart pub global activate flutterfire_cli\n'
      '  flutterfire configure',
    );
    return;
  }
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await FirebaseAuth.instance.setLanguageCode('es');
  await _initializeCrashlytics();
}

Future<void> _initializeCrashlytics() async {
  if (!DefaultFirebaseOptions.isConfigured) {
    return;
  }

  // En algunos builds release (R8 / Xiaomi) el registrar nativo no carga.
  // No debe impedir el arranque de la app.
  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  } catch (error, stack) {
    debugPrint('Crashlytics no disponible: $error');
    debugPrint('$stack');
    return;
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {}
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      unawaited(
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
      );
    } catch (_) {}
    return true;
  };
}
