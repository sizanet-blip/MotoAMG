import 'package:hive_flutter/hive_flutter.dart';
import 'package:moto_amg/core/api/motoamg_api_client.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/auth/data/datasources/privacy_acceptance_store.dart';
import 'package:moto_amg/features/auth/domain/entities/app_user.dart';

const _sessionBox = 'motoamg_mysql_session';
const _tokenKey = 'access_token';
const _uidKey = 'uid';
const _nameKey = 'display_name';
const _clubKey = 'current_club_id';
const _pendingClubKey = 'pending_club_request_id';
const _groupKey = 'current_group_id';
const _userKey = 'username';
const _emailKey = 'email';
const _privacyAtKey = 'privacy_accepted_at';
const _privacyVerKey = 'privacy_accepted_version';
const _soloKey = 'allow_solo_navigation';

class MysqlAuthSessionStore {
  Box<String>? _box;

  Future<Box<String>> _open() async {
    return _box ??= await Hive.openBox<String>(_sessionBox);
  }

  Future<void> save({
    required String accessToken,
    required AppUser user,
  }) async {
    final box = await _open();
    await box.put(_tokenKey, accessToken);
    await box.put(_uidKey, user.uid);
    await box.put(_nameKey, user.displayName);
    await box.put(_userKey, user.username ?? '');
    await box.put(_emailKey, user.email ?? '');
    await box.put(_clubKey, user.currentClubId ?? '');
    await box.put(_pendingClubKey, user.pendingClubRequestId ?? '');
    await box.put(_groupKey, user.currentGroupId ?? '');
    await box.put(_soloKey, user.allowSoloNavigation ? '1' : '0');
    await box.put(
      _privacyAtKey,
      user.privacyAcceptedAt?.toIso8601String() ?? '',
    );
    await box.put(_privacyVerKey, user.privacyAcceptedVersion ?? '');
  }

  Future<String?> readToken() async {
    final box = await _open();
    return box.get(_tokenKey);
  }

  Future<AppUser?> readUser() async {
    final box = await _open();
    final uid = box.get(_uidKey);
    if (uid == null || uid.isEmpty) return null;
    final privacyAtRaw = box.get(_privacyAtKey);
    DateTime? privacyAt;
    if (privacyAtRaw != null && privacyAtRaw.isNotEmpty) {
      privacyAt = DateTime.tryParse(privacyAtRaw);
    }
    final privacyVer = box.get(_privacyVerKey);
    return AppUser(
      uid: uid,
      displayName: box.get(_nameKey) ?? uid,
      username: () {
        final u = box.get(_userKey);
        return (u == null || u.isEmpty) ? null : u;
      }(),
      email: () {
        final e = box.get(_emailKey);
        return (e == null || e.isEmpty) ? null : e;
      }(),
      currentClubId: () {
        final c = box.get(_clubKey);
        return (c == null || c.isEmpty) ? null : c;
      }(),
      pendingClubRequestId: () {
        final p = box.get(_pendingClubKey);
        return (p == null || p.isEmpty) ? null : p;
      }(),
      currentGroupId: () {
        final g = box.get(_groupKey);
        return (g == null || g.isEmpty) ? null : g;
      }(),
      allowSoloNavigation: box.get(_soloKey) == '1',
      privacyAcceptedAt: privacyAt,
      privacyAcceptedVersion:
          (privacyVer == null || privacyVer.isEmpty) ? null : privacyVer,
      createdAt: DateTime.now(),
      provider: AuthProviderType.username,
    );
  }

  Future<void> clear() async {
    final box = await _open();
    await box.clear();
  }
}

class MysqlAuthRemoteDataSource {
  MysqlAuthRemoteDataSource(
    this._api,
    this._session, {
    PrivacyAcceptanceStore? privacyStore,
  }) : _privacy = privacyStore ?? PrivacyAcceptanceStore();

  final MotoAmgApiClient _api;
  final MysqlAuthSessionStore _session;
  final PrivacyAcceptanceStore _privacy;

  Future<String?> get sessionToken async =>
      _api.accessToken ?? await _session.readToken();

  void bindAccessToken(String token) => _api.setAccessToken(token);

  Future<AppUser> register({
    required String username,
    required String password,
    required String displayName,
    String? email,
  }) async {
    final data = await _api.post(
      '/motoamg/auth/register',
      body: {
        'username': username,
        'password': password,
        'displayName': displayName,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    return _persist(data);
  }

  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final data = await _api.post(
      '/motoamg/auth/login',
      body: {
        'username': username,
        'password': password,
      },
    );
    return _persist(data);
  }

  Future<AppUser> loginWithGoogle({
    required String idToken,
    required String mode,
    String? email,
    String? googleUserId,
  }) async {
    final prior = await _privacy.lookup(uid: googleUserId, email: email);
    final data = await _api.post(
      '/motoamg/auth/google',
      body: {
        'idToken': idToken,
        'mode': mode,
      },
    );
    var user = await _persist(data);
    if (user.needsPrivacyAcceptance &&
        prior != null &&
        prior.version.trim() == AppConstants.privacyPolicyVersion) {
      user = user.copyWith(
        privacyAcceptedVersion: prior.version,
        privacyAcceptedAt: prior.at ?? DateTime.now(),
      );
      final token = data['accessToken'];
      if (token is String && token.isNotEmpty) {
        await _session.save(accessToken: token, user: user);
      }
      await _rememberPrivacy(user);
    }
    if (googleUserId != null &&
        googleUserId.isNotEmpty &&
        !user.needsPrivacyAcceptance) {
      await _privacy.remember(
        uid: googleUserId,
        email: email ?? user.email,
        version: user.privacyAcceptedVersion!,
        at: user.privacyAcceptedAt,
      );
    }
    return user;
  }

  Future<AppUser> loginAsGuest({required String displayName}) async {
    final data = await _api.post(
      '/motoamg/auth/guest',
      body: {'displayName': displayName},
    );
    return _persist(data);
  }

  Future<AppUser?> restoreSession() async {
    final token = await _session.readToken();
    if (token == null || token.isEmpty) return null;
    _api.setAccessToken(token);
    final cached = await _session.readUser();
    try {
      final data = await _api.get('/motoamg/auth/me');
      final userMap = data['user'];
      if (userMap is! Map) {
        return cached == null ? null : await _withDurablePrivacy(cached);
      }
      var user = _userFromMap(Map<String, dynamic>.from(userMap));
      user = _mergePrivacy(user, cached);
      user = await _withDurablePrivacy(user);
      await _session.save(accessToken: token, user: user);
      return user;
    } catch (_) {
      if (cached != null) {
        return await _withDurablePrivacy(cached);
      }
      await _session.clear();
      _api.setAccessToken(null);
      return null;
    }
  }

  Future<AppUser?> fetchMe() async {
    final data = await _api.get('/motoamg/auth/me');
    final userMap = data['user'];
    if (userMap is! Map) return null;
    var user = _userFromMap(Map<String, dynamic>.from(userMap));
    final cached = await _session.readUser();
    user = _mergePrivacy(user, cached);
    user = await _withDurablePrivacy(user);
    final token = _api.accessToken ?? await _session.readToken();
    if (token != null && token.isNotEmpty) {
      await _session.save(accessToken: token, user: user);
    }
    return user;
  }

  Future<void> persistLocalUser(AppUser user) async {
    // Siempre guardar aceptación durable (no depende del JWT).
    await _rememberPrivacy(user);

    var token = _api.accessToken;
    if (token == null || token.isEmpty) {
      token = await _session.readToken();
      if (token != null && token.isNotEmpty) {
        _api.setAccessToken(token);
      }
    }
    if (token == null || token.isEmpty) {
      // Sin JWT no hay sesión API, pero la privacidad ya quedó guardada.
      return;
    }
    await _session.save(accessToken: token, user: user);
  }

  /// Guarda solo la aceptación de privacidad (uid/email), con o sin JWT.
  Future<AppUser> acceptPrivacy(AppUser user, {String? alsoUid}) async {
    final updated = user.copyWith(
      privacyAcceptedAt: DateTime.now(),
      privacyAcceptedVersion: AppConstants.privacyPolicyVersion,
    );
    await _rememberPrivacy(updated);
    if (alsoUid != null &&
        alsoUid.trim().isNotEmpty &&
        alsoUid.trim() != updated.uid) {
      await _privacy.remember(
        uid: alsoUid.trim(),
        email: updated.email,
        version: AppConstants.privacyPolicyVersion,
        at: updated.privacyAcceptedAt,
      );
    }
    var token = _api.accessToken ?? await _session.readToken();
    if (token != null && token.isNotEmpty) {
      _api.setAccessToken(token);
      await _session.save(accessToken: token, user: updated);
    }
    return updated;
  }

  Future<void> signOut() async {
    // La aceptación por uid/email se conserva a propósito.
    await _session.clear();
    _api.setAccessToken(null);
  }

  Future<AppUser> _persist(Map<String, dynamic> data) async {
    final token = data['accessToken'];
    final userMap = data['user'];
    if (token is! String || token.isEmpty || userMap is! Map) {
      throw const MotoAmgApiException('Respuesta de login incompleta');
    }
    var user = _userFromMap(Map<String, dynamic>.from(userMap));
    final cached = await _session.readUser();
    user = _mergePrivacy(user, cached);
    user = await _withDurablePrivacy(user);
    // Si aún no ha aceptado esta cuenta → AuthGate mostrará la pantalla.
    // No auto-aceptar aquí.
    _api.setAccessToken(token);
    await _session.save(accessToken: token, user: user);
    return user;
  }

  Future<void> _rememberPrivacy(AppUser user) async {
    final ver = user.privacyAcceptedVersion?.trim() ?? '';
    if (ver.isEmpty) return;
    await _privacy.remember(
      uid: user.uid,
      email: user.email,
      version: ver,
      at: user.privacyAcceptedAt,
    );
  }

  Future<AppUser> _withDurablePrivacy(AppUser user) async {
    await _rememberPrivacy(user);
    if (!user.needsPrivacyAcceptance) {
      return user;
    }
    return _privacy.applyIfAccepted(
      user: user,
      uid: user.uid,
      email: user.email,
      withPrivacy: (version, at) => user.copyWith(
        privacyAcceptedVersion: version,
        privacyAcceptedAt: at ?? DateTime.now(),
      ),
    );
  }

  AppUser _mergePrivacy(AppUser remote, AppUser? local) {
    if (local == null) return remote;
    final sameUid = local.uid == remote.uid;
    final sameEmail = (local.email?.trim().isNotEmpty == true) &&
        local.email!.trim().toLowerCase() ==
            (remote.email?.trim().toLowerCase() ?? '');
    if (!sameUid && !sameEmail) return remote;
    final ver = local.privacyAcceptedVersion;
    if (ver == null || ver.isEmpty) return remote;
    return remote.copyWith(
      privacyAcceptedAt: local.privacyAcceptedAt,
      privacyAcceptedVersion: ver,
      currentGroupId: remote.currentGroupId ?? local.currentGroupId,
    );
  }

  AppUser _userFromMap(Map<String, dynamic> map) {
    final providerRaw = '${map['authProvider'] ?? 'mysql'}';
    final provider = switch (providerRaw) {
      'google' => AuthProviderType.google,
      'guest' => AuthProviderType.anonymous,
      'email' => AuthProviderType.email,
      _ => AuthProviderType.username,
    };
    return AppUser(
      uid: '${map['uid']}',
      displayName: '${map['displayName'] ?? map['uid']}',
      username: map['username'] as String?,
      email: map['email'] as String?,
      currentClubId: map['currentClubId'] == null
          ? null
          : '${map['currentClubId']}',
      pendingClubRequestId: map['pendingClubRequestId'] == null
          ? null
          : '${map['pendingClubRequestId']}',
      allowSoloNavigation: map['allowSoloNavigation'] == true ||
          provider == AuthProviderType.anonymous,
      createdAt: DateTime.now(),
      provider: provider,
      privacyAcceptedVersion: null,
      privacyAcceptedAt: null,
    );
  }
}
