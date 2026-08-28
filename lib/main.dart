import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:loc_motos/app.dart';
import 'package:loc_motos/firebase_options.dart';
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
  runApp(const LocMotosApp());
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

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    !kDebugMode,
  );

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
    );
    return true;
  };
}
