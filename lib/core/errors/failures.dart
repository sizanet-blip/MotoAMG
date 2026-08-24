import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

final class LocationFailure extends Failure {
  const LocationFailure(super.message);
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
