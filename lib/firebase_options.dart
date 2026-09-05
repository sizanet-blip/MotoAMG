// File generated for Firebase project motoamg (MotoAMG).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static bool get isConfigured {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android.apiKey.isNotEmpty;
      case TargetPlatform.iOS:
        return ios.apiKey.isNotEmpty;
      default:
        return false;
    }
  }

  /// URL de RTDB (europe-west1). Crear la instancia en consola si aún no existe.
  static const realtimeDatabaseUrl =
      'https://motoamg-default-rtdb.europe-west1.firebasedatabase.app';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCZKZ01-jGDj0l7FJE6ocdIcc3pKitBxuk',
    appId: '1:853611010116:android:f09cba58855911438b0411',
    messagingSenderId: '853611010116',
    projectId: 'motoamg',
    storageBucket: 'motoamg.firebasestorage.app',
    databaseURL: realtimeDatabaseUrl,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA7UKExONGpLIuIZc998MdR0hBTULUzhm0',
    appId: '1:853611010116:ios:0d4cf0f1bea4ae058b0411',
    messagingSenderId: '853611010116',
    projectId: 'motoamg',
    storageBucket: 'motoamg.firebasestorage.app',
    databaseURL: realtimeDatabaseUrl,
    iosBundleId: 'es.albertomaestre.motoamg',
    iosClientId:
        '853611010116-1719vbon3r386q8ufb87o7qeab750nbg.apps.googleusercontent.com',
  );

  /// OAuth Web client (client_type 3) — Google Sign-In `serverClientId`.
  static const String googleWebClientId =
      '853611010116-06t64fsbs4d1jn28qhmsmfj8c4fhii89.apps.googleusercontent.com';
}
