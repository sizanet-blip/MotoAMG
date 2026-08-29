import 'package:equatable/equatable.dart';

enum IntercomConnectionStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  unavailable,
  error,
}

class IntercomSessionState extends Equatable {
  const IntercomSessionState({
    this.status = IntercomConnectionStatus.idle,
    this.groupId,
    this.speakEnabled = true,
    this.listenEnabled = true,
    this.desiredActive = false,
    this.hostCount = 0,
    this.errorMessage,
    this.participantCount = 0,
    this.remoteSpeakerNames = const [],
    this.localTransmitting = false,
  });

  static const initial = IntercomSessionState();

  final IntercomConnectionStatus status;
  final String? groupId;
  final bool speakEnabled;
  final bool listenEnabled;
  final bool desiredActive;
  final int hostCount;
  final String? errorMessage;
  final int participantCount;

  /// Compañeros que están hablando ahora (nombres).
  final List<String> remoteSpeakerNames;

  /// El mic local está enviando voz (VAD abierto).
  final bool localTransmitting;

  bool get isConnected => status == IntercomConnectionStatus.connected;

  bool get isBusy =>
      status == IntercomConnectionStatus.connecting ||
      status == IntercomConnectionStatus.reconnecting;

  bool get someoneSpeakingRemote => remoteSpeakerNames.isNotEmpty;

  String get statusLabel {
    if (!desiredActive) {
      return 'Intercom apagado';
    }
    return switch (status) {
      IntercomConnectionStatus.idle => 'Intercom apagado',
      IntercomConnectionStatus.connecting => 'Conectando…',
      IntercomConnectionStatus.connected => 'Intercom activo',
      IntercomConnectionStatus.reconnecting => 'Reconectando…',
      IntercomConnectionStatus.unavailable => 'Sin cobertura',
      IntercomConnectionStatus.error => errorMessage ?? 'Error de intercom',
    };
  }

  IntercomSessionState copyWith({
    IntercomConnectionStatus? status,
    String? groupId,
    bool clearGroupId = false,
    bool? speakEnabled,
    bool? listenEnabled,
    bool? desiredActive,
    int? hostCount,
    String? errorMessage,
    bool clearError = false,
    int? participantCount,
    List<String>? remoteSpeakerNames,
    bool? localTransmitting,
  }) {
    return IntercomSessionState(
      status: status ?? this.status,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      speakEnabled: speakEnabled ?? this.speakEnabled,
      listenEnabled: listenEnabled ?? this.listenEnabled,
      desiredActive: desiredActive ?? this.desiredActive,
      hostCount: hostCount ?? this.hostCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      participantCount: participantCount ?? this.participantCount,
      remoteSpeakerNames: remoteSpeakerNames ?? this.remoteSpeakerNames,
      localTransmitting: localTransmitting ?? this.localTransmitting,
    );
  }

  @override
  List<Object?> get props => [
        status,
        groupId,
        speakEnabled,
        listenEnabled,
        desiredActive,
        hostCount,
        errorMessage,
        participantCount,
        remoteSpeakerNames,
        localTransmitting,
      ];
}
