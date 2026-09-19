import 'dart:async';
import 'dart:convert';

import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/groups/domain/entities/group_incident.dart';
import 'package:moto_amg/features/groups/domain/entities/group_stop.dart';
import 'package:moto_amg/features/groups/domain/entities/group_voice_announcement.dart';
import 'package:moto_amg/features/groups/domain/exceptions/group_exceptions.dart';
import 'package:moto_amg/features/tracking/data/datasources/gps_token_client.dart';
import 'package:moto_amg/features/tracking/domain/entities/live_location.dart';
import 'package:moto_amg/features/tracking/domain/exceptions/location_exceptions.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef GpsIdentityLookup = ({String uid, String displayName})? Function();

/// Canal en vivo del grupo: GPS + avisos + paradas + voz (mismo WebSocket).
class GpsWsLocationDataSource {
  GpsWsLocationDataSource({
    required GpsIdentityLookup identityLookup,
    GpsTokenClient? tokenClient,
  })  : _identityLookup = identityLookup,
        _tokenClient = tokenClient ?? GpsTokenClient();

  final GpsIdentityLookup _identityLookup;
  final GpsTokenClient _tokenClient;
  final Map<String, _GroupGpsSession> _sessions = {};

  Stream<List<LiveLocation>> watchGroup(String groupId) {
    try {
      return _ensureSession(groupId).watchLocations();
    } on LocationException catch (error) {
      return Stream.error(error);
    }
  }

  Stream<List<GroupIncident>> watchIncidents(String groupId) {
    try {
      return _ensureSession(groupId).watchIncidents();
    } on LocationException catch (error) {
      return Stream.error(GroupException(error.message));
    }
  }

  Stream<List<GroupStop>> watchStops(String groupId) {
    try {
      return _ensureSession(groupId).watchStops();
    } on LocationException catch (error) {
      return Stream.error(GroupException(error.message));
    }
  }

  Stream<List<GroupVoiceAnnouncement>> watchVoice(String groupId) {
    try {
      return _ensureSession(groupId).watchVoice();
    } on LocationException catch (error) {
      return Stream.error(GroupException(error.message));
    }
  }

  _GroupGpsSession _ensureSession(String groupId) {
    final existing = _sessions[groupId];
    if (existing != null) {
      return existing;
    }

    final identity = _identityLookup();
    if (identity == null || identity.uid.isEmpty) {
      throw const LocationException('No hay usuario para unirse al GPS');
    }

    final session = _GroupGpsSession(
      groupId: groupId,
      uid: identity.uid,
      displayName: identity.displayName,
      tokenClient: _tokenClient,
      onClosed: () => _sessions.remove(groupId),
    );
    _sessions[groupId] = session;
    unawaited(session.start());
    return session;
  }

  Future<_GroupGpsSession> _readySession(String groupId) async {
    final session = _ensureSession(groupId);
    await session.waitUntilReady();
    return session;
  }

  Future<void> publish(LiveLocation location) async {
    final session = _ensureSession(location.groupId);
    await session.waitUntilReady();
    await session.publishLocation(location);
  }

  Future<void> clear({required String groupId, required String uid}) async {
    final session = _sessions[groupId];
    if (session == null) return;
    await session.leave();
  }

  Future<void> publishIncident(String groupId, GroupIncident incident) async {
    try {
      final session = await _readySession(groupId);
      await session.publishIncident(incident);
    } on LocationException catch (e) {
      throw GroupException(e.message);
    }
  }

  Future<void> clearIncident({
    required String groupId,
    required String uid,
  }) async {
    try {
      final session = await _readySession(groupId);
      await session.clearIncident(uid);
    } on LocationException catch (e) {
      throw GroupException(e.message);
    }
  }

  Future<String> publishStop(String groupId, GroupStop stop) async {
    try {
      final session = await _readySession(groupId);
      return await session.publishStop(stop);
    } on LocationException catch (e) {
      throw GroupException(e.message);
    }
  }

  Future<void> clearStop({
    required String groupId,
    required String stopId,
  }) async {
    try {
      final session = await _readySession(groupId);
      await session.clearStop(stopId);
    } on LocationException catch (e) {
      throw GroupException(e.message);
    }
  }

  Future<void> publishVoice({
    required String groupId,
    required GroupVoiceAnnouncement announcement,
  }) async {
    try {
      final session = await _readySession(groupId);
      await session.publishVoice(announcement);
    } on LocationException catch (e) {
      throw GroupException(e.message);
    }
  }
}

class _GroupGpsSession {
  _GroupGpsSession({
    required this.groupId,
    required this.uid,
    required this.displayName,
    required this.tokenClient,
    required this.onClosed,
  });

  final String groupId;
  final String uid;
  final String displayName;
  final GpsTokenClient tokenClient;
  final void Function() onClosed;

  final _locationsController =
      StreamController<List<LiveLocation>>.broadcast();
  final _incidentsController =
      StreamController<List<GroupIncident>>.broadcast();
  final _stopsController = StreamController<List<GroupStop>>.broadcast();
  final _voiceController =
      StreamController<List<GroupVoiceAnnouncement>>.broadcast();

  final Map<String, LiveLocation> _locations = {};
  final Map<String, GroupIncident> _incidents = {};
  final Map<String, GroupStop> _stops = {};
  final List<GroupVoiceAnnouncement> _voice = [];

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _joined = false;
  final Completer<void> _ready = Completer<void>();
  Completer<String>? _pendingStopId;

  Stream<List<LiveLocation>> watchLocations() async* {
    yield _locationsSnapshot();
    yield* _locationsController.stream;
  }

  Stream<List<GroupIncident>> watchIncidents() async* {
    yield _incidentsSnapshot();
    yield* _incidentsController.stream;
  }

  Stream<List<GroupStop>> watchStops() async* {
    yield _stopsSnapshot();
    yield* _stopsController.stream;
  }

  Stream<List<GroupVoiceAnnouncement>> watchVoice() async* {
    yield List<GroupVoiceAnnouncement>.from(_voice);
    yield* _voiceController.stream;
  }

  Future<void> waitUntilReady() async {
    if (_joined) return;
    await _ready.future.timeout(const Duration(seconds: 15));
  }

  Future<void> start() async {
    try {
      final token = await tokenClient.fetchToken(
        uid: uid,
        groupId: groupId,
        displayName: displayName,
      );
      final channel = WebSocketChannel.connect(Uri.parse(AppConstants.gpsWsUrl));
      _channel = channel;
      _sub = channel.stream.listen(
        _onMessage,
        onError: (Object error, StackTrace st) {
          if (!_locationsController.isClosed) {
            _locationsController.addError(
              LocationException('GPS WebSocket: $error'),
              st,
            );
          }
          unawaited(dispose());
        },
        onDone: () => unawaited(dispose()),
      );
      channel.sink.add(
        jsonEncode({
          'type': 'join',
          'groupId': groupId,
          'token': token,
        }),
      );
      await _ready.future.timeout(const Duration(seconds: 15));
    } catch (error) {
      if (!_ready.isCompleted) {
        _ready.completeError(error);
      }
      if (!_locationsController.isClosed) {
        _locationsController.addError(
          error is LocationException
              ? error
              : LocationException('No se pudo conectar al GPS. $error'),
        );
      }
      await dispose();
    }
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic>? msg;
    try {
      final decoded =
          jsonDecode(raw is String ? raw : utf8.decode(raw as List<int>));
      if (decoded is Map) {
        msg = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return;
    }
    if (msg == null) return;

    final type = msg['type'];
    if (type == 'joined') {
      _joined = true;
      _locations.clear();
      _incidents.clear();
      _stops.clear();
      final list = msg['locations'];
      if (list is List) {
        for (final item in list) {
          final loc = _parseLocation(item);
          if (loc != null) {
            _locations[loc.uid] = loc;
          }
        }
      }
      final incidents = msg['incidents'];
      if (incidents is List) {
        for (final item in incidents) {
          final incident = _parseIncident(item);
          if (incident != null) {
            _incidents[incident.uid] = incident;
          }
        }
      }
      final stops = msg['stops'];
      if (stops is List) {
        for (final item in stops) {
          final stop = _parseStop(item);
          if (stop != null) {
            _stops[stop.id] = stop;
          }
        }
      }
      _emitLocations();
      _emitIncidents();
      _emitStops();
      if (!_ready.isCompleted) {
        _ready.complete();
      }
      return;
    }

    if (type == 'location') {
      final loc = _parseLocation(msg['location']);
      if (loc != null) {
        _locations[loc.uid] = loc;
        _emitLocations();
      }
      return;
    }

    if (type == 'clear') {
      final clearUid = '${msg['uid'] ?? ''}';
      if (clearUid.isNotEmpty) {
        _locations.remove(clearUid);
        _emitLocations();
      }
      return;
    }

    if (type == 'incident') {
      final incident = _parseIncident(msg['incident']);
      if (incident != null) {
        _incidents[incident.uid] = incident;
        _emitIncidents();
      }
      return;
    }

    if (type == 'incident_cleared') {
      final clearUid = '${msg['uid'] ?? ''}';
      if (clearUid.isNotEmpty) {
        _incidents.remove(clearUid);
        _emitIncidents();
      }
      return;
    }

    if (type == 'stop') {
      final stop = _parseStop(msg['stop']);
      if (stop != null) {
        _stops[stop.id] = stop;
        _emitStops();
      }
      return;
    }

    if (type == 'stop_cleared') {
      final stopId = '${msg['stopId'] ?? ''}';
      if (stopId.isNotEmpty) {
        _stops.remove(stopId);
        _emitStops();
      }
      return;
    }

    if (type == 'stop_published') {
      final stopId = '${msg['stopId'] ?? ''}';
      final pending = _pendingStopId;
      if (pending != null && !pending.isCompleted && stopId.isNotEmpty) {
        pending.complete(stopId);
      }
      return;
    }

    if (type == 'voice') {
      final announcement = _parseVoice(msg['announcement']);
      if (announcement != null) {
        _voice.add(announcement);
        if (_voice.length > 20) {
          _voice.removeRange(0, _voice.length - 20);
        }
        if (!_voiceController.isClosed) {
          _voiceController.add(List<GroupVoiceAnnouncement>.from(_voice));
        }
      }
      return;
    }

    if (type == 'error') {
      final message = '${msg['message'] ?? 'error GPS'}';
      if (!_ready.isCompleted) {
        _ready.completeError(LocationException(message));
      }
      if (!_locationsController.isClosed) {
        _locationsController.addError(LocationException(message));
      }
      final pending = _pendingStopId;
      if (pending != null && !pending.isCompleted) {
        pending.completeError(GroupException(message));
      }
    }
  }

  LiveLocation? _parseLocation(Object? data) {
    if (data is! Map) return null;
    final map = <String, dynamic>{
      for (final e in data.entries) '${e.key}': e.value,
    };
    final lat = _asDouble(map['lat']);
    final lng = _asDouble(map['lng']);
    if (lat == null || lng == null) return null;
    final id = '${map['uid'] ?? ''}'.trim();
    if (id.isEmpty) return null;
    final updatedRaw = map['updatedAt'];
    final updatedAt = updatedRaw is num
        ? DateTime.fromMillisecondsSinceEpoch(updatedRaw.toInt())
        : DateTime.now();
    return LiveLocation(
      uid: id,
      groupId: '${map['groupId'] ?? groupId}',
      lat: lat,
      lng: lng,
      heading: _asDouble(map['heading']) ?? 0,
      speed: _asDouble(map['speed']) ?? 0,
      updatedAt: updatedAt,
      displayName: '${map['displayName'] ?? ''}',
      hasSignal: map['hasSignal'] is bool ? map['hasSignal'] as bool : true,
    );
  }

  GroupIncident? _parseIncident(Object? data) {
    if (data is! Map) return null;
    final map = Map<dynamic, dynamic>.from(data);
    final id = '${map['uid'] ?? ''}'.trim();
    if (id.isEmpty) return null;
    try {
      final incident = GroupIncident.fromRtdb(id, map);
      return incident.active ? incident : null;
    } catch (_) {
      return null;
    }
  }

  GroupStop? _parseStop(Object? data) {
    if (data is! Map) return null;
    final map = Map<dynamic, dynamic>.from(data);
    final id = '${map['id'] ?? ''}'.trim();
    if (id.isEmpty) return null;
    try {
      final stop = GroupStop.fromRtdb(id, map);
      return stop.active ? stop : null;
    } catch (_) {
      return null;
    }
  }

  GroupVoiceAnnouncement? _parseVoice(Object? data) {
    if (data is! Map) return null;
    final map = Map<dynamic, dynamic>.from(data);
    final id = '${map['id'] ?? ''}'.trim();
    if (id.isEmpty) return null;
    try {
      return GroupVoiceAnnouncement.fromRtdb(id, map);
    } catch (_) {
      return null;
    }
  }

  List<LiveLocation> _locationsSnapshot() =>
      _locations.values.toList(growable: false);

  List<GroupIncident> _incidentsSnapshot() {
    final list = _incidents.values.toList();
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  List<GroupStop> _stopsSnapshot() {
    final list = _stops.values.toList();
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  void _emitLocations() {
    if (!_locationsController.isClosed) {
      _locationsController.add(_locationsSnapshot());
    }
  }

  void _emitIncidents() {
    if (!_incidentsController.isClosed) {
      _incidentsController.add(_incidentsSnapshot());
    }
  }

  void _emitStops() {
    if (!_stopsController.isClosed) {
      _stopsController.add(_stopsSnapshot());
    }
  }

  Future<void> publishLocation(LiveLocation location) async {
    if (!_joined || _channel == null) {
      throw const LocationException('GPS: aún no conectado al grupo');
    }
    _channel!.sink.add(
      jsonEncode({
        'type': 'publish',
        'lat': location.lat,
        'lng': location.lng,
        'heading': location.heading,
        'speed': location.speed,
        'hasSignal': location.hasSignal,
      }),
    );
    _locations[location.uid] = location;
    _emitLocations();
  }

  Future<void> publishIncident(GroupIncident incident) async {
    if (!_joined || _channel == null) {
      throw const LocationException('GPS: aún no conectado al grupo');
    }
    final payload = incident.toRtdb();
    _channel!.sink.add(
      jsonEncode({
        'type': 'publish_incident',
        'incident': payload,
      }),
    );
    // Eco local (el server también reenvía a todos; dedupe por mapa).
    _incidents[incident.uid] = incident;
    _emitIncidents();
  }

  Future<void> clearIncident(String clearUid) async {
    if (!_joined || _channel == null) {
      throw const LocationException('GPS: aún no conectado al grupo');
    }
    _channel!.sink.add(
      jsonEncode({
        'type': 'clear_incident',
        'uid': clearUid,
      }),
    );
    _incidents.remove(clearUid);
    _emitIncidents();
  }

  Future<String> publishStop(GroupStop stop) async {
    if (!_joined || _channel == null) {
      throw const LocationException('GPS: aún no conectado al grupo');
    }
    final pending = Completer<String>();
    _pendingStopId = pending;
    _channel!.sink.add(
      jsonEncode({
        'type': 'publish_stop',
        'stop': {
          ...stop.toRtdb(),
          if (stop.id.isNotEmpty) 'id': stop.id,
        },
      }),
    );
    final stopId = await pending.future.timeout(const Duration(seconds: 10));
    _pendingStopId = null;
    final saved = GroupStop(
      id: stopId,
      type: stop.type,
      point: stop.point,
      at: stop.at,
      createdBy: stop.createdBy,
      displayName: stop.displayName,
    );
    _stops[stopId] = saved;
    _emitStops();
    return stopId;
  }

  Future<void> clearStop(String stopId) async {
    if (!_joined || _channel == null) {
      throw const LocationException('GPS: aún no conectado al grupo');
    }
    _channel!.sink.add(
      jsonEncode({
        'type': 'clear_stop',
        'stopId': stopId,
      }),
    );
    _stops.remove(stopId);
    _emitStops();
  }

  Future<void> publishVoice(GroupVoiceAnnouncement announcement) async {
    if (!_joined || _channel == null) {
      throw const LocationException('GPS: aún no conectado al grupo');
    }
    _channel!.sink.add(
      jsonEncode({
        'type': 'publish_voice',
        'announcement': announcement.toRtdb(),
      }),
    );
  }

  Future<void> leave() async {
    try {
      _channel?.sink.add(jsonEncode({'type': 'leave'}));
    } catch (_) {}
    await dispose();
  }

  Future<void> dispose() async {
    _joined = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (!_locationsController.isClosed) {
      await _locationsController.close();
    }
    if (!_incidentsController.isClosed) {
      await _incidentsController.close();
    }
    if (!_stopsController.isClosed) {
      await _stopsController.close();
    }
    if (!_voiceController.isClosed) {
      await _voiceController.close();
    }
    onClosed();
  }
}

double? _asDouble(Object? value) {
  if (value is num) {
    final n = value.toDouble();
    return n.isFinite ? n : null;
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
