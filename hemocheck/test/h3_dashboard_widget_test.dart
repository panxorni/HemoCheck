import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/models/bloque_horario.dart';
import 'package:hemocheck/screens/dashboard_donante_screen.dart';

Widget _tarjeta(BloqueHorario bloque, {bool yaInscrito = false}) {
  return MaterialApp(
    home: Scaffold(
      body: BloqueCard(
        bloque: bloque,
        yaInscrito: yaInscrito,
        onReservar: () {},
        onCancelar: () {},
      ),
    ),
  );
}

BloqueHorario _bloque({
  required int reservasActuales,
  bool cerrado = false,
}) {
  return BloqueHorario(
    id: 'bloque-1',
    sedeId: '123',
    fecha: '2026-11-20',
    horaInicio: '09:00',
    horaFin: '10:00',
    capacidadMaxima: 10,
    reservasActuales: reservasActuales,
    cerrado: cerrado,
  );
}

ElevatedButton _boton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton));

void main() {
  group('BloqueCard - Dashboard del donante (HU3)', () {
    testWidgets('Bloque lleno: muestra "Lleno" y el botón está deshabilitado',
        (tester) async {
      await tester.pumpWidget(_tarjeta(_bloque(reservasActuales: 10)));

      expect(find.text('Lleno'), findsOneWidget);
      expect(find.text('Reservar'), findsNothing);
      expect(_boton(tester).onPressed, isNull);
    });

    testWidgets('Bloque con cupos: muestra "Reservar" y el botón está habilitado',
        (tester) async {
      await tester.pumpWidget(_tarjeta(_bloque(reservasActuales: 4)));

      expect(find.text('Reservar'), findsOneWidget);
      expect(_boton(tester).onPressed, isNotNull);
    });

    testWidgets('Donante ya inscrito: muestra "Cancelar" y está habilitado',
        (tester) async {
      await tester.pumpWidget(
          _tarjeta(_bloque(reservasActuales: 10), yaInscrito: true));

      expect(find.text('Cancelar'), findsOneWidget);
      expect(_boton(tester).onPressed, isNotNull);
    });

    testWidgets('Bloque cerrado: muestra "Cerrado" y está deshabilitado',
        (tester) async {
      await tester
          .pumpWidget(_tarjeta(_bloque(reservasActuales: 2, cerrado: true)));

      expect(find.text('Cerrado'), findsOneWidget);
      expect(_boton(tester).onPressed, isNull);
    });
  });
}
