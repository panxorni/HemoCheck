import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/models/evaluacion.dart';
import 'package:hemocheck/screens/registrar_donacion_screen.dart';
import 'package:hemocheck/services/donacion_service.dart';

Evaluacion _evaluacion(ResultadoEvaluacion resultado) => Evaluacion(
      citaId: 'CITA-1',
      donanteRut: '12345678-5',
      profesionalId: 'PROF-01',
      fecha: DateTime(2026, 11, 10),
      resultado: resultado,
      fechaHabilitacion: resultado == ResultadoEvaluacion.diferidoTemporal
          ? DateTime(2026, 12, 1)
          : null,
    );

Widget _pantalla(
  Evaluacion? evaluacion, {
  ExisteDonacion? existe,
  PersistenciaAtomicaCallback? persistir,
}) {
  return MaterialApp(
    home: RegistrarDonacionScreen(
      evaluacion: evaluacion,
      donanteRut: '12345678-5',
      tipoSangre: TipoSangre.oPos,
      sedeId: '123',
      profesionalId: 'PROF-01',
      service: DonacionService(
        persistirAtomicamente: persistir ?? (_) async {},
      ),
      existeDonacion: existe ?? (_) async => false,
    ),
  );
}

void main() {
  testWidgets('Donante diferido: muestra bloqueo y no el botón de confirmar',
      (tester) async {
    await tester.pumpWidget(
        _pantalla(_evaluacion(ResultadoEvaluacion.diferidoTemporal)));

    expect(find.text('Donación bloqueada'), findsOneWidget);
    expect(find.text('Confirmar Donación'), findsNothing);
  });

  testWidgets('Sin evaluación: muestra bloqueo', (tester) async {
    await tester.pumpWidget(_pantalla(null));

    expect(find.text('Donación bloqueada'), findsOneWidget);
    expect(find.text('Confirmar Donación'), findsNothing);
  });

  testWidgets('Donante apto: muestra el formulario y registra la donación',
      (tester) async {
    ResultadoRegistroDonacion? guardado;
    await tester.pumpWidget(_pantalla(
      _evaluacion(ResultadoEvaluacion.apto),
      persistir: (r) async => guardado = r,
    ));

    expect(find.text('Donación bloqueada'), findsNothing);
    expect(find.text('Confirmar Donación'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '450');
    await tester.tap(find.text('Confirmar Donación'));
    await tester.pumpAndSettle();

    expect(guardado, isNotNull);
    expect(guardado!.donacion.volumenMl, 450);
    expect(find.textContaining('BOLSA-'), findsOneWidget);
    expect(find.text('Donación registrada'), findsOneWidget);
  });

  testWidgets('Volumen inválido: muestra error y no guarda', (tester) async {
    var llamadas = 0;
    await tester.pumpWidget(_pantalla(
      _evaluacion(ResultadoEvaluacion.apto),
      persistir: (_) async => llamadas++,
    ));

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Confirmar Donación'));
    await tester.pump();

    expect(find.text('El volumen debe ser mayor a 0 ml'), findsOneWidget);
    expect(llamadas, 0);
  });

  testWidgets('Donación duplicada en la cita: muestra el aviso y no guarda',
      (tester) async {
    var llamadas = 0;
    await tester.pumpWidget(_pantalla(
      _evaluacion(ResultadoEvaluacion.apto),
      existe: (_) async => true,
      persistir: (_) async => llamadas++,
    ));

    await tester.enterText(find.byType(TextFormField), '450');
    await tester.tap(find.text('Confirmar Donación'));
    await tester.pumpAndSettle();

    expect(find.text('Ya existe una donación registrada para esta cita.'),
        findsOneWidget);
    expect(llamadas, 0);
  });
}