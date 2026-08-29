import 'package:equatable/equatable.dart';

/// Preferencias locales del intercom (defaults Hablar/Oír).
class IntercomPreferences extends Equatable {
  const IntercomPreferences({
    this.defaultSpeak = true,
    this.defaultListen = true,
  });

  static const defaults = IntercomPreferences();

  /// Micrófono abierto al conectar (salvo mute manual).
  final bool defaultSpeak;

  /// Escuchar al pelotón al conectar.
  final bool defaultListen;

  IntercomPreferences copyWith({
    bool? defaultSpeak,
    bool? defaultListen,
  }) {
    return IntercomPreferences(
      defaultSpeak: defaultSpeak ?? this.defaultSpeak,
      defaultListen: defaultListen ?? this.defaultListen,
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultSpeak': defaultSpeak,
        'defaultListen': defaultListen,
      };

  factory IntercomPreferences.fromJson(Map<String, dynamic> json) {
    return IntercomPreferences(
      defaultSpeak: json['defaultSpeak'] as bool? ?? true,
      defaultListen: json['defaultListen'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [defaultSpeak, defaultListen];
}
