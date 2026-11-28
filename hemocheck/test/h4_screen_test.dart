import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hemocheck/screens/evaluacion_clinica_screen.dart';
import 'package:hemocheck/services/auth_service.dart';
import 'package:hemocheck/services/evaluacion_service.dart';

Widget _crearPantalla() {
  final firestore = FakeFirebaseFirestore();
  return MaterialApp(
    home: EvaluacionClinicaScreen(
      firestore: firestore,
      // Se pasa un AuthService simulado para no depender de Firebase real
      authService: AuthService(auth: MockFirebaseAuth(), db: firestore),
      evaluacionService: EvaluacionService(firestore: firestore),
    ),
  );
}

void main() {
  testWidgets('peso 48 muestra el bloqueo clínico al guardar',
      (WidgetTester tester) async {
    // Pantalla alta para que el formulario completo quede visible
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_crearPantalla());

    // Ingresar peso 48
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Peso (kg)'),
      '48',
    );

    // Presionar guardar
    final botonGuardar = find.text('Guardar Evaluación');
    await tester.ensureVisible(botonGuardar);
    await tester.pumpAndSettle();
    await tester.tap(botonGuardar);
    await tester.pumpAndSettle();

    // Verificar el mensaje de bloqueo
    expect(
      find.text('Bloqueo clínico: el peso mínimo para donar es 50 kg'),
      findsOneWidget,
    );
  });
}