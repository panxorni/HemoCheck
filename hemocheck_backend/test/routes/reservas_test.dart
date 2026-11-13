import 'package:dart_frog/dart_frog.dart';
import 'package:hemocheck_backend/db.dart';
import 'package:hemocheck_backend/models/bloque_horario.dart';
import 'package:hemocheck_backend/models/cita.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/sedes/[sedeId]/horarios/[horarioId]/reservas.dart'
as route;

class MockRequestContext extends Mock implements RequestContext {}

class MockRequest extends Mock implements Request {}

/// Simula un POST de reserva enviado por el donante indicado.
MockRequestContext _solicitud(String donanteId) {
  final context = MockRequestContext();
  final request = MockRequest();
  when(() => context.request).thenReturn(request);
  when(() => request.method).thenReturn(HttpMethod.post);
  when(() => request.json()).thenAnswer((_) async => {'donanteId': donanteId});
  return context;
}

void _crearBloque({int capacidad = 5, int reservas = 0}) {
  tablaHorarios.add(
    BloqueHorario(
      id: 'bloque-1',
      sedeId: 'sede-1',
      fecha: '2026-11-20',
      horaInicio: '09:00',
      horaFin: '10:00',
      capacidadMaxima: capacidad,
      reservasActuales: reservas,
    ),
  );
}

int _reservasDelBloque() => tablaHorarios.first.reservasActuales;

void main() {
  setUp(() {
    tablaHorarios.clear();
    tablaCitas.clear();
  });

  group('POST /sedes/[sedeId]/horarios/[horarioId]/reservas', () {
    test('Test 1 (Reserva exitosa): devuelve 201, crea la cita activa y '
        'descuenta un cupo', () async {
      _crearBloque(capacidad: 5);

      final response = await route.onRequest(
        _solicitud('donante-1'),
        'sede-1',
        'bloque-1',
      );

      expect(response.statusCode, equals(201));
      final body = await response.json() as Map<String, dynamic>;
      expect(body['estado'], equals('activa'));
      expect(body['donanteId'], equals('donante-1'));
      expect(body['bloqueId'], equals('bloque-1'));
      expect(tablaCitas.length, equals(1));
      expect(_reservasDelBloque(), equals(1));
    });

    test('Test 2 (Bloque sin cupo): devuelve 409 si el bloque está lleno',
            () async {
          _crearBloque(capacidad: 3, reservas: 3);

          final response = await route.onRequest(
            _solicitud('donante-1'),
            'sede-1',
            'bloque-1',
          );

          expect(response.statusCode, equals(409));
          final body = await response.json() as Map<String, dynamic>;
          expect(
            body['error'],
            equals('El bloque seleccionado no tiene cupos disponibles.'),
          );
          expect(tablaCitas, isEmpty);
          expect(_reservasDelBloque(), equals(3));
        });

    test('Test 3 (Cita activa existente): devuelve 409 si el donante ya '
        'tiene una cita activa', () async {
      _crearBloque();
      tablaCitas.add(
        const Cita(
          id: 'cita-anterior',
          donanteId: 'donante-1',
          sedeId: 'sede-1',
          bloqueId: 'otro-bloque',
          fechaReserva: '2026-11-10T10:00:00.000',
        ),
      );

      final response = await route.onRequest(
        _solicitud('donante-1'),
        'sede-1',
        'bloque-1',
      );

      expect(response.statusCode, equals(409));
      final body = await response.json() as Map<String, dynamic>;
      expect(
        body['error'],
        equals('Ya tienes una cita activa. No puedes reservar otra.'),
      );
      expect(tablaCitas.length, equals(1));
      expect(_reservasDelBloque(), equals(0));
    });

    test('Test 4 (Reserva simultánea): con 1 cupo, solo una de dos reservas '
        'simultáneas se confirma', () async {
      _crearBloque(capacidad: 1);

      final respuestas = await Future.wait([
        route.onRequest(_solicitud('donante-1'), 'sede-1', 'bloque-1'),
        route.onRequest(_solicitud('donante-2'), 'sede-1', 'bloque-1'),
      ]);

      final codigos = respuestas.map((r) => r.statusCode).toList()..sort();
      expect(codigos, equals([201, 409]));
      expect(tablaCitas.length, equals(1));
      expect(_reservasDelBloque(), equals(1));
    });

    test('Bloque inexistente: devuelve 404', () async {
      final response = await route.onRequest(
        _solicitud('donante-1'),
        'sede-1',
        'no-existe',
      );

      expect(response.statusCode, equals(404));
      expect(tablaCitas, isEmpty);
    });
  });
}