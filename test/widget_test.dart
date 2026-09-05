import 'package:flutter_test/flutter_test.dart';
import 'package:moto_amg/app.dart';
import 'package:moto_amg/core/constants/app_constants.dart';
import 'package:moto_amg/features/auth/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('muestra las dos formas de entrar', (tester) async {
    await tester.pumpWidget(
      MotoAmgApp(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Entrar con Google'), findsOneWidget);
    expect(find.text('Entrar como invitado'), findsOneWidget);
  });
}
