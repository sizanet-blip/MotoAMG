import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moto_amg/features/navigation/domain/exceptions/navigation_exceptions.dart';
import 'package:moto_amg/features/navigation/domain/exceptions/navigation_user_message.dart';

void main() {
  test('mantiene el mensaje de NavigationException', () {
    expect(
      navigationUserMessage(const RouteNotFoundException()),
      NavigationUserMessages.noViableRoute,
    );
  });

  test('timeout sin detalle técnico', () {
    expect(
      navigationUserMessage(TimeoutException('x')),
      NavigationUserMessages.timeout,
    );
  });

  test('sin red sin detalle técnico', () {
    expect(
      navigationUserMessage(const SocketException('Failed host lookup')),
      NavigationUserMessages.noConnection,
    );
  });

  test('error desconocido genérico', () {
    expect(
      navigationUserMessage(StateError('boom')),
      NavigationUserMessages.generic,
    );
  });
}
