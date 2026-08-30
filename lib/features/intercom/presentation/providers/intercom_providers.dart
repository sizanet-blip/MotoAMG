import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:loc_motos/features/intercom/data/datasources/intercom_token_remote_datasource.dart';
import 'package:loc_motos/features/intercom/data/intercom_audio_session.dart';
import 'package:loc_motos/features/intercom/data/repositories/intercom_preferences_repository.dart';
import 'package:loc_motos/features/intercom/domain/entities/intercom_preferences.dart';
import 'package:loc_motos/features/intercom/domain/entities/intercom_session_state.dart';
import 'package:loc_motos/features/intercom/domain/entities/intercom_token_credentials.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:permission_handler/permission_handler.dart';

final intercomPreferencesRepositoryProvider =
    Provider<IntercomPreferencesRepository>(
  (_) => IntercomPreferencesRepository(),
);

final intercomTokenRemoteDataSourceProvider =
    Provider<IntercomTokenRemoteDataSource>(
  (_) => IntercomTokenRemoteDataSource(),
);

final intercomPreferencesProvider =
    NotifierProvider<IntercomPreferencesController, IntercomPreferences>(
  IntercomPreferencesController.new,
);

class IntercomPreferencesController extends Notifier<IntercomPreferences> {
  @override
  IntercomPreferences build() {
    Future.microtask(_hydrate);
    return IntercomPreferences.defaults;
  }

  Future<void> _hydrate() async {
    final loaded = await ref.read(intercomPreferencesRepositoryProvider).load();
    state = loaded;
  }

  Future<void> _persist(IntercomPreferences next) async {
    state = next;
    await ref.read(intercomPreferencesRepositoryProvider).save(next);
  }

  Future<void> setDefaultSpeak(bool value) {
    return _persist(state.copyWith(defaultSpeak: value));
  }

  Future<void> setDefaultListen(bool value) {
    return _persist(state.copyWith(defaultListen: value));
  }
}

final intercomSessionProvider =
    NotifierProvider<IntercomSessionController, IntercomSessionState>(
  IntercomSessionController.new,
);

class IntercomSessionController extends Notifier<IntercomSessionState> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _reconnectTimer;
  var _connectGeneration = 0;
  var _manualSpeakOverride = false;
  var _manualListenOverride = false;
  var _intentionalDisconnect = false;
  var _reconnectAttempt = 0;
  var _wasOnline = true;
  var _systemMusicDucked = false;

  static const _maxReconnectAttempts = 8;
  /// Tras agotar reintentos rápidos, seguir probando cada X (p. ej. al llegar a ciudad).
  static const _slowRetrySeconds = 45;

  @override
  IntercomSessionState build() {
    ref.onDispose(_disposeAll);
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    return IntercomSessionState.initial;
  }

  Future<void> retainHost({required String groupId}) async {
    final nextCount = state.hostCount + 1;
    final prefs = ref.read(intercomPreferencesProvider);
    final speak = _manualSpeakOverride ? state.speakEnabled : prefs.defaultSpeak;
    final listen =
        _manualListenOverride ? state.listenEnabled : prefs.defaultListen;

    state = state.copyWith(
      hostCount: nextCount,
      groupId: groupId,
      speakEnabled: speak,
      listenEnabled: listen,
      clearError: true,
    );
  }

  Future<void> releaseHost() async {
    final nextCount = (state.hostCount - 1).clamp(0, 1000);
    state = state.copyWith(hostCount: nextCount);
    if (nextCount == 0) {
      await disconnect(clearDesired: true);
    }
  }

  Future<void> setDesiredActive(bool active) async {
    _reconnectAttempt = 0;
    if (active) {
      state = state.copyWith(desiredActive: true, clearError: true);
      if (state.hostCount <= 0) {
        state = state.copyWith(
          status: IntercomConnectionStatus.error,
          errorMessage: 'Abre el mapa del grupo para usar el intercom',
        );
        return;
      }
      await _ensureConnected();
      return;
    }
    _connectGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    state = state.copyWith(
      desiredActive: false,
      status: IntercomConnectionStatus.idle,
      clearError: true,
      participantCount: 0,
      remoteSpeakerNames: const [],
      localTransmitting: false,
    );
    await _setIntercomDuck(false);
    await _tearDownRoom();
  }

  Future<void> setSpeakEnabled(bool enabled) async {
    _manualSpeakOverride = true;
    state = state.copyWith(speakEnabled: enabled, localTransmitting: false);
    await _applyPublishState();
  }

  Future<void> setListenEnabled(bool enabled) async {
    _manualListenOverride = true;
    state = state.copyWith(listenEnabled: enabled);
    await _applySubscribeState();
  }

  Future<void> _ensureConnected() async {
    if (!state.desiredActive || state.hostCount <= 0) {
      return;
    }
    final groupId = state.groupId;
    if (groupId == null || groupId.isEmpty) {
      return;
    }
    if (_room != null &&
        _room!.connectionState == ConnectionState.connected &&
        state.isConnected) {
      _reconnectAttempt = 0;
      return;
    }
    if (state.status == IntercomConnectionStatus.connecting) {
      return;
    }

    final online = await _hasNetwork();
    if (!online) {
      // Forzar que el próximo “online” del plugin dispare reconexión.
      _wasOnline = false;
      state = state.copyWith(
        status: IntercomConnectionStatus.unavailable,
        errorMessage: 'Sin cobertura, intercom no disponible',
      );
      return;
    }

    final micOk = await _ensureMicPermission();
    if (!micOk) {
      state = state.copyWith(
        status: IntercomConnectionStatus.error,
        errorMessage: 'Permiso de micrófono necesario',
      );
      return;
    }

    final generation = ++_connectGeneration;
    final isRetry = _reconnectAttempt > 0;
    state = state.copyWith(
      status: isRetry
          ? IntercomConnectionStatus.reconnecting
          : IntercomConnectionStatus.connecting,
      clearError: true,
    );

    try {
      final creds = await ref
          .read(intercomTokenRemoteDataSourceProvider)
          .fetchToken(groupId: groupId);
      if (generation != _connectGeneration || !state.desiredActive) {
        return;
      }
      await _connectRoom(creds);
      if (generation != _connectGeneration) {
        return;
      }
      _reconnectAttempt = 0;
      state = state.copyWith(
        status: IntercomConnectionStatus.connected,
        participantCount: (_room?.remoteParticipants.length ?? 0) + 1,
        clearError: true,
      );
    } on IntercomTokenException catch (e) {
      if (generation != _connectGeneration) {
        return;
      }
      debugPrint('Intercom token failed: ${e.message}');
      state = state.copyWith(
        status: IntercomConnectionStatus.error,
        errorMessage: e.message,
      );
      _scheduleReconnect();
    } catch (e, st) {
      debugPrint('Intercom connect failed: $e\n$st');
      if (generation != _connectGeneration) {
        return;
      }
      state = state.copyWith(
        status: IntercomConnectionStatus.error,
        errorMessage: _shortError(e),
      );
      _scheduleReconnect();
    }
  }

  Future<void> _connectRoom(IntercomTokenCredentials creds) async {
    await _tearDownRoom();
    // Antes de crear la Room: modo idle (mezcla con música), no «llamada».
    await IntercomAudioSession.applyIdle();
    _systemMusicDucked = false;

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          highPassFilter: true,
          stopAudioCaptureOnMute: false,
        ),
        defaultAudioPublishOptions: AudioPublishOptions(
          dtx: true,
        ),
      ),
    );

    final listener = room.createListener();
    listener
      ..on<RoomDisconnectedEvent>((event) {
        if (_intentionalDisconnect) {
          return;
        }
        if (!state.desiredActive || state.hostCount <= 0) {
          state = state.copyWith(status: IntercomConnectionStatus.idle);
          return;
        }
        debugPrint('Intercom disconnected: ${event.reason}');
        unawaited(_setIntercomDuck(false));
        state = state.copyWith(
          status: IntercomConnectionStatus.reconnecting,
          errorMessage: 'Reconectando…',
          remoteSpeakerNames: const [],
          localTransmitting: false,
        );
        _scheduleReconnect(immediate: true);
      })
      ..on<ParticipantConnectedEvent>((_) {
        state = state.copyWith(
          participantCount: (_room?.remoteParticipants.length ?? 0) + 1,
        );
      })
      ..on<ParticipantDisconnectedEvent>((_) {
        state = state.copyWith(
          participantCount: (_room?.remoteParticipants.length ?? 0) + 1,
        );
      })
      ..on<ActiveSpeakersChangedEvent>(_onActiveSpeakersChanged);

    _room = room;
    _listener = listener;

    await room.connect(
      creds.url,
      creds.token,
      connectOptions: const ConnectOptions(
        autoSubscribe: true,
      ),
    );

    await _applyPublishState();
    await _applySubscribeState();
  }

  void _onActiveSpeakersChanged(ActiveSpeakersChangedEvent event) {
    final localSid = _room?.localParticipant?.sid;
    final names = <String>[];
    var localSpeaking = false;
    for (final speaker in event.speakers) {
      if (speaker.sid == localSid) {
        localSpeaking = true;
        continue;
      }
      final name = speaker.name.trim().isNotEmpty
          ? speaker.name.trim()
          : speaker.identity;
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
    final transmitting = localSpeaking && state.speakEnabled;
    final speakersChanged = !listEquals(names, state.remoteSpeakerNames);
    final localChanged = transmitting != state.localTransmitting;
    if (speakersChanged || localChanged) {
      state = state.copyWith(
        remoteSpeakerNames: names,
        localTransmitting: transmitting,
      );
    }
    final remoteTalking = names.isNotEmpty && state.listenEnabled;
    if (speakersChanged) {
      unawaited(_setNavVoiceDuck(remoteTalking));
    }
    if (speakersChanged || localChanged) {
      unawaited(_setSystemMusicDuck(remoteTalking || transmitting));
    }
  }

  /// Baja el TTS de navegación mientras habla alguien por intercom.
  Future<void> _setNavVoiceDuck(bool duck) async {
    try {
      await ref.read(navigationVoiceServiceProvider).setIntercomDuck(duck);
    } catch (e) {
      debugPrint('Intercom nav duck failed: $e');
    }
  }

  /// Baja la música del sistema (Spotify, etc.) solo mientras hay voz.
  Future<void> _setSystemMusicDuck(bool duck) async {
    if (_systemMusicDucked == duck) {
      return;
    }
    _systemMusicDucked = duck;
    try {
      if (duck) {
        await IntercomAudioSession.applySpeaking();
      } else {
        await IntercomAudioSession.applyIdle();
      }
    } catch (e) {
      debugPrint('Intercom system audio duck failed: $e');
      _systemMusicDucked = !duck;
    }
  }

  Future<void> _setIntercomDuck(bool duck) async {
    await _setNavVoiceDuck(duck);
    if (!duck) {
      await _setSystemMusicDuck(false);
    }
  }

  Future<void> _applyPublishState() async {
    final room = _room;
    if (room == null || room.connectionState != ConnectionState.connected) {
      return;
    }
    try {
      await room.localParticipant?.setMicrophoneEnabled(state.speakEnabled);
      if (!state.speakEnabled) {
        state = state.copyWith(localTransmitting: false);
      }
    } catch (e) {
      debugPrint('Intercom mic toggle failed: $e');
    }
  }

  Future<void> _applySubscribeState() async {
    final room = _room;
    if (room == null) {
      return;
    }
    final listen = state.listenEnabled;
    if (!listen) {
      unawaited(_setIntercomDuck(false));
    }
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.audioTrackPublications) {
        try {
          if (listen) {
            await publication.subscribe();
          } else {
            await publication.unsubscribe();
          }
        } catch (e) {
          debugPrint('Intercom subscribe toggle failed: $e');
        }
      }
    }
  }

  Future<void> disconnect({bool clearDesired = false}) async {
    _connectGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    await _setIntercomDuck(false);
    await _tearDownRoom();
    _manualSpeakOverride = false;
    _manualListenOverride = false;
    state = state.copyWith(
      status: IntercomConnectionStatus.idle,
      desiredActive: clearDesired ? false : state.desiredActive,
      clearGroupId: clearDesired && state.hostCount == 0,
      clearError: true,
      participantCount: 0,
      remoteSpeakerNames: const [],
      localTransmitting: false,
    );
  }

  void _scheduleReconnect({bool immediate = false}) {
    if (!state.desiredActive || state.hostCount <= 0) {
      return;
    }
    _reconnectTimer?.cancel();

    if (_reconnectAttempt >= _maxReconnectAttempts) {
      // No tirar la toalla del todo: muchos móviles siguen “online” con red
      // inútil; al mejorar cobertura no siempre hay evento none→online.
      state = state.copyWith(
        status: IntercomConnectionStatus.reconnecting,
        errorMessage:
            'Red inestable. Reintentando automáticamente…',
      );
      _reconnectTimer = Timer(const Duration(seconds: _slowRetrySeconds), () {
        if (!state.desiredActive || state.hostCount <= 0) {
          return;
        }
        _reconnectAttempt = 0;
        unawaited(_ensureConnected());
      });
      return;
    }

    _reconnectAttempt++;
    final seconds =
        immediate ? 1 : (2 * _reconnectAttempt).clamp(2, 15);
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      unawaited(_ensureConnected());
    });
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (!state.desiredActive || state.hostCount <= 0) {
      _wasOnline = online;
      return;
    }

    if (!online) {
      _wasOnline = false;
      await _setIntercomDuck(false);
      state = state.copyWith(
        status: IntercomConnectionStatus.unavailable,
        errorMessage: 'Sin cobertura, intercom no disponible',
        remoteSpeakerNames: const [],
        localTransmitting: false,
      );
      return;
    }

    final regained = !_wasOnline;
    _wasOnline = true;

    final alreadyUp = state.isConnected &&
        _room != null &&
        _room!.connectionState == ConnectionState.connected;
    if (alreadyUp) {
      return;
    }

    // Recuperación de cobertura O cambio de red mientras no estamos conectados
    // (p. ej. llegas a ciudad con datos que “nunca” pasaron por none).
    final needsRetry = regained ||
        state.status == IntercomConnectionStatus.unavailable ||
        state.status == IntercomConnectionStatus.error ||
        state.status == IntercomConnectionStatus.reconnecting;

    if (!needsRetry) {
      return;
    }

    _reconnectAttempt = 0;
    state = state.copyWith(
      status: IntercomConnectionStatus.reconnecting,
      clearError: true,
    );
    _scheduleReconnect(immediate: true);
  }

  Future<bool> _hasNetwork() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> _ensureMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }
    status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _tearDownRoom() async {
    _intentionalDisconnect = true;
    final listener = _listener;
    _listener = null;
    await listener?.dispose();

    final room = _room;
    _room = null;
    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {}
      try {
        await room.dispose();
      } catch (_) {}
    }
    _systemMusicDucked = false;
    await IntercomAudioSession.releaseOnDisconnect();
    _intentionalDisconnect = false;
  }

  String _shortError(Object e) {
    final raw = e.toString();
    if (raw.length <= 80) {
      return raw;
    }
    return '${raw.substring(0, 77)}…';
  }

  Future<void> _disposeAll() async {
    _reconnectTimer?.cancel();
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    await _setIntercomDuck(false);
    await _tearDownRoom();
  }
}
