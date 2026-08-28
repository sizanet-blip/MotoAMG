import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/auth/data/models/user_model.dart';
import 'package:loc_motos/features/auth/data/services/secret_wrap.dart';
import 'package:loc_motos/features/auth/data/services/username_auth.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/domain/exceptions/auth_exceptions.dart';
import 'package:loc_motos/firebase_options.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    FirebaseDatabase? database,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _database =
           database ??
           FirebaseDatabase.instanceFor(
             app: Firebase.app(),
             databaseURL: DefaultFirebaseOptions.realtimeDatabaseUrl,
           ),
       _googleSignIn =
           googleSignIn ??
           GoogleSignIn(
             scopes: const ['email'],
             clientId: defaultTargetPlatform == TargetPlatform.iOS
                 ? DefaultFirebaseOptions.ios.iosClientId
                 : null,
             serverClientId:
                 '128161523972-povb28ju9fbrcq0jsg7ljlcj7sbef1an.apps.googleusercontent.com',
           );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;
  final GoogleSignIn _googleSignIn;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _firestore.collection(AppConstants.usernamesCollection);

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection(AppConstants.groupsCollection);

  CollectionReference<Map<String, dynamic>> _members(String groupId) {
    return _groups.doc(groupId).collection(AppConstants.membersSubcollection);
  }

  Stream<User?> userChanges() => _auth.userChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthCancelledException();
      }
      final tokens = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: tokens.accessToken,
        idToken: tokens.idToken,
      );
      return _auth.signInWithCredential(credential);
    } on AuthCancelledException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'invalid-credential') {
        throw const AuthException(
          'No se pudo validar la cuenta de Google. '
          'En Android añade el SHA-1 de debug en Firebase; '
          'en iPhone comprueba el URL scheme de Google Sign-In.',
        );
      }
      throw AuthException(_mapFirebaseError(error));
    } catch (error) {
      throw AuthException(_mapGoogleError(error));
    }
  }

  Future<UserCredential> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseError(error));
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseError(error));
    }
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseError(error));
    }
  }

  Future<UserCredential> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final record = await _usernameRecord(username);
    late final String secret;
    try {
      secret = SecretWrap.unwrap(
        wrapped: record['wrappedSecret'] as String,
        password: password,
        salt: record['salt'] as String,
      );
    } catch (_) {
      throw const AuthException('Usuario o contraseña incorrectos.');
    }
    try {
      return await _auth.signInWithEmailAndPassword(
        email: record['authEmail'] as String,
        password: secret,
      );
    } on FirebaseAuthException {
      throw const AuthException('Usuario o contraseña incorrectos.');
    }
  }

  Future<({UserCredential credential, String recoveryKey, String username})>
  registerWithUsername({
    required String username,
    required String password,
  }) async {
    final normalized = UsernameAuth.normalize(username);
    final recoveryKey = UsernameAuth.generateRecoveryKey();
    final salt = UsernameAuth.generateSalt();
    final wrapped = SecretWrap.wrap(
      secret: recoveryKey,
      password: password,
      salt: salt,
    );
    final authEmail = UsernameAuth.authEmail(normalized);

    late final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: recoveryKey,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        throw const AuthException('Ese usuario ya está cogido. Prueba otro.');
      }
      throw AuthException(_mapFirebaseError(error));
    }

    final uid = credential.user?.uid;
    if (uid == null) {
      throw const AuthException('No se pudo crear la cuenta.');
    }

    try {
      await _usernames.doc(normalized).set({
        'uid': uid,
        'authEmail': authEmail,
        'salt': salt,
        'wrappedSecret': wrapped,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      try {
        await credential.user?.delete();
      } catch (_) {}
      throw AuthException(
        'No se pudo reservar el usuario. ${error.toString()}',
      );
    }

    return (
      credential: credential,
      recoveryKey: recoveryKey,
      username: normalized,
    );
  }

  Future<UserCredential> recoverUsernamePassword({
    required String username,
    required String recoveryKey,
    required String newPassword,
  }) async {
    final record = await _usernameRecord(
      username,
      notFoundMessage: 'No hay ninguna cuenta con ese usuario.',
    );
    final key = UsernameAuth.normalizeRecoveryKey(recoveryKey);
    late final UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: record['authEmail'] as String,
        password: key,
      );
    } on FirebaseAuthException {
      throw const AuthException('La clave de recuperación no es correcta.');
    }

    final salt = UsernameAuth.generateSalt();
    final wrapped = SecretWrap.wrap(
      secret: key,
      password: newPassword,
      salt: salt,
    );
    try {
      await _usernames.doc(UsernameAuth.normalize(username)).update({
        'salt': salt,
        'wrappedSecret': wrapped,
      });
    } on FirebaseException catch (error) {
      throw AuthException(
        'Entraste, pero no se pudo guardar la nueva clave. '
        '${error.message ?? error.code}',
      );
    }
    return credential;
  }

  Future<String> revealRecoveryKey({
    required String username,
    required String password,
  }) async {
    final record = await _usernameRecord(
      username,
      notFoundMessage: 'No hay ninguna cuenta con ese usuario.',
    );
    try {
      return SecretWrap.unwrap(
        wrapped: record['wrappedSecret'] as String,
        password: password,
        salt: record['salt'] as String,
      );
    } catch (_) {
      throw const AuthException('Contraseña incorrecta.');
    }
  }

  Future<Map<String, dynamic>> _usernameRecord(
    String username, {
    String notFoundMessage = 'Usuario o contraseña incorrectos.',
  }) async {
    final normalized = UsernameAuth.normalize(username);
    try {
      final snapshot = await _usernames.doc(normalized).get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw AuthException(notFoundMessage);
      }
      return data;
    } on AuthException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AuthException(
        'No se pudo leer el usuario. ${error.message ?? error.code}',
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.setLanguageCode('es');
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') {
        return;
      }
      throw AuthException(_mapFirebaseError(error));
    }
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) {
      return;
    }
    try {
      await _auth.setLanguageCode('es');
      await user.sendEmailVerification();
    } catch (_) {}
  }

  Future<void> updateFirebaseDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('No hay sesión activa.');
    }
    await user.updateDisplayName(displayName);
    await user.reload();
  }

  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      await _deleteGuestSession(user);
      return;
    }
    try {
      if (_googleSignIn.currentUser != null) {
        await _googleSignIn.signOut();
      }
    } catch (_) {
      // Emulador sin Play Store: no hay sesión de Google.
    }
    await _auth.signOut();
  }

  /// Quita al invitado del grupo, GPS, perfil y cuenta anónima.
  Future<void> _deleteGuestSession(User user) async {
    final uid = user.uid;
    String? groupId;
    try {
      groupId = (await _users.doc(uid).get()).data()?['currentGroupId'] as String?;
    } catch (_) {}

    if (groupId != null && groupId.isNotEmpty) {
      try {
        final groupSnap = await _groups.doc(groupId).get();
        final batch = _firestore.batch();
        batch.delete(_members(groupId).doc(uid));
        batch.set(_users.doc(uid), {
          'currentGroupId': null,
        }, SetOptions(merge: true));
        if (groupSnap.exists && groupSnap.data()?['ownerId'] == uid) {
          batch.update(_groups.doc(groupId), {'isActive': false});
        }
        await batch.commit();
      } catch (_) {
        try {
          await _members(groupId).doc(uid).delete();
        } catch (_) {}
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
      try {
        await _database
            .ref('${AppConstants.liveLocationsPath}/$groupId/$uid')
            .remove();
      } catch (_) {}
    }

    try {
      final memberships = await _users
          .doc(uid)
          .collection(AppConstants.membershipsSubcollection)
          .get();
      for (final doc in memberships.docs) {
        try {
          await _members(doc.id).doc(uid).delete();
        } catch (_) {}
        try {
          await doc.reference.delete();
        } catch (_) {}
        try {
          await _database
              .ref('${AppConstants.liveLocationsPath}/${doc.id}/$uid')
              .remove();
        } catch (_) {}
      }
    } catch (_) {}

    try {
      await _users.doc(uid).delete();
    } catch (_) {}

    try {
      await user.delete();
    } catch (_) {
      await _auth.signOut();
    }
  }

  Future<UserModel?> fetchUser(String uid) async {
    try {
      final snapshot = await _users.doc(uid).get();
      if (!snapshot.exists) {
        return null;
      }
      return UserModel.fromFirestore(snapshot);
    } on FirebaseException catch (error) {
      throw AuthException(
        'No se pudo leer tu perfil. ${error.message ?? error.code}',
      );
    }
  }

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserModel.fromFirestore(snapshot);
    });
  }

  Future<UserModel> upsertUser(AppUser user) async {
    final doc = _users.doc(user.uid);
    try {
      final existing = await doc.get();
      final model = UserModel.fromEntity(user);
      if (!existing.exists) {
        await doc.set(model.toFirestore());
        return model;
      }
      await doc.set({
        'displayName': model.displayName,
        'email': model.email,
        'photoUrl': model.photoUrl,
        'provider': _providerKey(model.provider),
        'phoneNumber': model.phoneNumber,
        if (model.username != null) 'username': model.username,
      }, SetOptions(merge: true));
      final updated = await doc.get();
      return UserModel.fromFirestore(updated);
    } on FirebaseException catch (error) {
      throw AuthException(
        'No se pudo guardar tu perfil. ${error.message ?? error.code}',
      );
    }
  }

  Future<UserModel> saveProfile(AppUser user) async {
    try {
      await updateFirebaseDisplayName(user.displayName);
    } catch (_) {}
    final doc = _users.doc(user.uid);
    try {
      await doc.set({
        'displayName': user.displayName,
        'phoneNumber': user.phoneNumber,
        'bikeBrand': user.bikeBrand,
        'bikeModel': user.bikeModel,
        'bikeYear': user.bikeYear,
        'bikeColor': user.bikeColor,
        'bikePlate': user.bikePlate,
        'vehicles': [for (final v in user.vehicles) v.toJson()],
        'activeVehicleId': user.activeVehicleId,
      }, SetOptions(merge: true));
      await _syncProfileToGroups(user);
      final updated = await doc.get();
      return UserModel.fromFirestore(updated);
    } on FirebaseException catch (error) {
      throw AuthException(
        'No se pudo guardar tu perfil. ${error.message ?? error.code}',
      );
    }
  }

  Future<void> _syncProfileToGroups(AppUser user) async {
    final groupIds = <String>{};
    if (user.currentGroupId != null && user.currentGroupId!.isNotEmpty) {
      groupIds.add(user.currentGroupId!);
    }
    try {
      final memberships = await _users
          .doc(user.uid)
          .collection(AppConstants.membershipsSubcollection)
          .get();
      groupIds.addAll(memberships.docs.map((doc) => doc.id));
    } catch (_) {}
    for (final groupId in groupIds) {
      try {
        final memberRef = _members(groupId).doc(user.uid);
        final existing = await memberRef.get();
        if (!existing.exists) {
          continue;
        }
        await memberRef.set({
          'displayName': user.displayName,
          'bikeBrand': user.bikeBrand,
          'bikeModel': user.bikeModel,
          'bikePlate': user.bikePlate,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> changeEmailPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw const AuthException('No hay una cuenta de correo activa.');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseError(error));
    }
  }

  Future<void> changeUsernamePassword({
    required String username,
    required String currentPassword,
    required String newPassword,
  }) async {
    final record = await _usernameRecord(username);
    late final String secret;
    try {
      secret = SecretWrap.unwrap(
        wrapped: record['wrappedSecret'] as String,
        password: currentPassword,
        salt: record['salt'] as String,
      );
    } catch (_) {
      throw const AuthException('La contraseña actual no es correcta.');
    }
    final salt = UsernameAuth.generateSalt();
    final wrapped = SecretWrap.wrap(
      secret: secret,
      password: newPassword,
      salt: salt,
    );
    try {
      await _usernames.doc(UsernameAuth.normalize(username)).update({
        'salt': salt,
        'wrappedSecret': wrapped,
      });
    } on FirebaseException catch (error) {
      throw AuthException(
        'No se pudo cambiar la contraseña. ${error.message ?? error.code}',
      );
    }
  }

  AppUser userFromFirebase(User user) {
    final email = user.email;
    final username = UsernameAuth.usernameFromEmail(email);
    return AppUser(
      uid: user.uid,
      displayName: user.displayName ?? '',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      provider: _providerOf(user),
      phoneNumber: user.phoneNumber,
      email: username == null ? email : null,
      username: username,
      photoUrl: user.photoURL,
    );
  }

  AuthProviderType _providerOf(User user) {
    if (user.isAnonymous) {
      return AuthProviderType.anonymous;
    }
    final hasGoogle = user.providerData.any(
      (info) => info.providerId == 'google.com',
    );
    if (hasGoogle) {
      return AuthProviderType.google;
    }
    if (UsernameAuth.isSyntheticEmail(user.email)) {
      return AuthProviderType.username;
    }
    return AuthProviderType.email;
  }

  String _providerKey(AuthProviderType provider) {
    return switch (provider) {
      AuthProviderType.google => 'google',
      AuthProviderType.email => 'email',
      AuthProviderType.username => 'username',
      AuthProviderType.anonymous => 'anonymous',
    };
  }

  String _mapFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'operation-not-allowed':
      case 'admin-restricted-operation':
        return 'Este tipo de acceso no está activado. '
            'En Firebase: Authentication → Sign-in method.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa Internet e inténtalo otra vez.';
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return 'Esa cuenta ya existe con otro método de acceso.';
      case 'email-already-in-use':
        return 'Ese correo ya tiene cuenta. Entra con él o recupera la clave.';
      case 'invalid-email':
        return 'Ese correo no es válido.';
      case 'weak-password':
        return 'La contraseña es demasiado corta.';
      case 'user-disabled':
        return 'Esta cuenta está desactivada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Correo o contraseña incorrectos.';
      case 'requires-recent-login':
        return 'Por seguridad, cierra sesión y entra otra vez para cambiar la contraseña.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento e inténtalo otra vez.';
      default:
        return error.message ?? 'No se pudo iniciar sesión (${error.code}).';
    }
  }

  String _mapGoogleError(Object error) {
    final text = error.toString();
    if (text.contains('ApiException: 10') || text.contains('DEVELOPER_ERROR')) {
      return 'Google Sign-In no está configurado. '
          'Añade el SHA-1 de debug en Firebase y vuelve a descargar '
          'google-services.json.';
    }
    if (text.contains('ApiException: 7') || text.contains('NETWORK')) {
      return 'Sin conexión. Revisa Internet e inténtalo otra vez.';
    }
    if (text.contains('ApiException: 12501') || text.contains('canceled')) {
      throw const AuthCancelledException();
    }
    return 'No se pudo entrar con Google. $text';
  }
}
