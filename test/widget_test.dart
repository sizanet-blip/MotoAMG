import 'package:flutter_test/flutter_test.dart';
import 'package:loc_motos/app.dart';
import 'package:loc_motos/core/constants/app_constants.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('muestra las dos formas de entrar', (tester) async {
    await tester.pumpWidget(
      LocMotosApp(
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
